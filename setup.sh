#!/bin/bash
# Deployment script for Tailscale Ollama on NixOS

set -e # Exit on error

echo "===================================="
echo "LOCKBOX INFRA TEST SETUP"
echo "===================================="
echo

# Check if we're on NixOS
if ! command -v nixos-rebuild &> /dev/null; then
    echo "❌ This script requires NixOS. Please install NixOS first."
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root."
    echo "Please run with: sudo $0"
    exit 1
fi

echo "✅ Verified NixOS environment"

# Check for Tailscale auth key
echo
echo "Tailscale Setup"
echo "--------------"
echo "You need a Tailscale auth key for automatic authentication."
echo "You can get this from https://login.tailscale.com/admin/settings/keys"
echo

read -p "Do you have a Tailscale auth key? (y/n): " have_key

if [ "$have_key" != "y" ] && [ "$have_key" != "Y" ]; then
    echo
    echo "Please obtain a Tailscale auth key before proceeding."
    echo "Visit https://login.tailscale.com/admin/settings/keys to create one."
    exit 1
fi

echo
read -p "Enter your Tailscale auth key: " tailscale_key

# Create the auth key file
mkdir -p /var/lib/tailscale
echo "$tailscale_key" > /var/lib/tailscale/authkey
chmod 600 /var/lib/tailscale/authkey

echo "✅ Tailscale auth key configured"

# Copy configuration files
echo
echo "Installing NixOS configuration..."

# Check if configuration already includes our file
if grep -q "ollama-config.nix" /etc/nixos/configuration.nix; then
    echo "Configuration already includes ollama-config.nix"
else
    # Copy our configuration
    cp $(dirname "$0")/nix/host.nix /etc/nixos/ollama-config.nix
    echo "import ./ollama-config.nix" >> /etc/nixos/configuration.nix
    echo "✅ Configuration files installed"
fi

# Apply configuration
echo
echo "Applying NixOS configuration..."
nixos-rebuild switch

echo
echo "✅ Deployment complete!"
echo
echo "Next steps:"
echo "1. Pull an AI model: pull-ai-model llama3:8b"
echo "2. Access OpenWebUI at http://$(hostname):3000 or via Tailscale"
echo "3. Check service status with: check-ai-services"
echo

exit 0
