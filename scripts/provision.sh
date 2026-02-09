#!/usr/bin/env bash
# Provision an AWS EC2 GPU instance and install NixOS via nixos-anywhere
#
# Prerequisites:
#   - aws CLI (configured: aws configure)
#   - nix with flakes enabled
#   - nixos-anywhere (nix run github:nix-community/nixos-anywhere)
#   - An EC2 key pair (for initial SSH access)
#
# Environment variables (from .env):
#   AWS_REGION         — AWS region (default: us-east-1)
#   AWS_KEY_PAIR       — EC2 key pair name
#   AWS_SUBNET_ID      — Subnet to launch into (must have public IP assignment)
#   TAILSCALE_AUTH_KEY  — Tailscale auth key for the new node

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLAKE_PATH="$REPO_ROOT/nix"

# Instance settings
INSTANCE_NAME="gpu-lab"
INSTANCE_TYPE="${AWS_INSTANCE_TYPE:-g4dn.xlarge}" # 1x T4 GPU
REGION="${AWS_REGION:-us-east-1}"

# --- Preflight checks ---

for cmd in aws nix ssh jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not installed" >&2
    exit 1
  fi
done

if [[ -z "${AWS_KEY_PAIR:-}" ]]; then
  echo "Error: AWS_KEY_PAIR is not set" >&2
  exit 1
fi

if [[ -z "${AWS_SUBNET_ID:-}" ]]; then
  echo "Error: AWS_SUBNET_ID is not set" >&2
  exit 1
fi

if [[ -z "${TAILSCALE_AUTH_KEY:-}" ]]; then
  echo "Error: TAILSCALE_AUTH_KEY is not set" >&2
  exit 1
fi

# --- Find Ubuntu AMI ---

echo "Finding latest Ubuntu 24.04 AMI in $REGION..."
AMI_ID=$(aws ec2 describe-images \
  --region "$REGION" \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
             "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

if [[ "$AMI_ID" == "None" || -z "$AMI_ID" ]]; then
  echo "Error: Could not find Ubuntu 24.04 AMI" >&2
  exit 1
fi
echo "Using AMI: $AMI_ID"

# --- Create security group ---

VPC_ID=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --subnet-ids "$AWS_SUBNET_ID" \
  --query 'Subnets[0].VpcId' \
  --output text)

SG_NAME="gpu-lab-provision"
SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || true)

if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
  echo "Creating security group '$SG_NAME'..."
  SG_ID=$(aws ec2 create-security-group \
    --region "$REGION" \
    --group-name "$SG_NAME" \
    --description "Temporary SG for gpu-lab provisioning — SSH only" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' \
    --output text)

  aws ec2 authorize-security-group-ingress \
    --region "$REGION" \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0
fi
echo "Security group: $SG_ID"

# --- Launch instance ---

echo "Launching $INSTANCE_TYPE instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$AWS_KEY_PAIR" \
  --subnet-id "$AWS_SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp3"}}]' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance launched: $INSTANCE_ID"
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Public IP: $PUBLIC_IP"

# --- Wait for SSH ---

echo "Waiting for SSH to become available..."
for i in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "ubuntu@$PUBLIC_IP" true 2>/dev/null; then
    echo "SSH is ready."
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "Error: SSH not available after 150s" >&2
    exit 1
  fi
  sleep 5
done

# --- Prepare extra files for nixos-anywhere ---
# Tailscale auth key gets placed into the new NixOS system

EXTRA_FILES=$(mktemp -d)
mkdir -p "$EXTRA_FILES/var/lib/tailscale"
echo "$TAILSCALE_AUTH_KEY" > "$EXTRA_FILES/var/lib/tailscale/authkey"
chmod 600 "$EXTRA_FILES/var/lib/tailscale/authkey"

# --- Install NixOS via nixos-anywhere ---

echo "Installing NixOS via nixos-anywhere..."
echo "This will wipe Ubuntu and install NixOS with our flake config."
echo "Flake: $FLAKE_PATH#gpu-lab"
echo ""

nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE_PATH#gpu-lab" \
  --extra-files "$EXTRA_FILES" \
  "root@$PUBLIC_IP"

rm -rf "$EXTRA_FILES"

# --- Done ---

echo ""
echo "=========================================="
echo " NixOS installed successfully!"
echo "=========================================="
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "Public IP:   $PUBLIC_IP"
echo ""
echo "The instance will reboot into NixOS with k3s and Tailscale."
echo "Wait a minute for Tailscale to connect, then:"
echo ""
echo "  1. Find the Tailscale IP:  tailscale status  (or check the Tailscale admin console)"
echo "  2. Update ansible/inventory.ini with the Tailscale IP"
echo "  3. Create k8s secrets:     ansible-playbook -i ansible/inventory.ini ansible/playbooks/secrets.yml"
echo "  4. Deploy services:        ansible-playbook -i ansible/inventory.ini ansible/playbooks/deploy.yml"
echo ""
echo "To lock down the security group after Tailscale is connected:"
echo "  aws ec2 revoke-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0"
echo ""
