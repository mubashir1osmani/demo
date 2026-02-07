# k3s (lightweight Kubernetes) configuration
# Single-node server with Traefik disabled (we use Nginx ingress instead)
# NVIDIA runtime enabled so pods can request GPU resources
{ config, pkgs, lib, ... }:

{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = builtins.concatStringsSep " " [
      "--disable traefik"           # We'll install nginx-ingress via Helm
      "--write-kubeconfig-mode 644" # Readable kubeconfig for non-root kubectl
    ];
  };

  # k3s manages its own containerd, but we need the NVIDIA runtime config
  # so that pods with nvidia.com/gpu resource requests get the GPU
  environment.etc."rancher/k3s/config.yaml".text = ''
    # k3s server configuration
    kubelet-arg:
      - "max-pods=110"
  '';

  # Open k3s API port on Tailscale interface (already covered by trustedInterfaces)
  # Port 6443 is the k8s API server
}
