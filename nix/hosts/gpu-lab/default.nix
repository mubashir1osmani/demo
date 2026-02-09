# GPU Lab — main configuration
# Imports all modules for the Digital Ocean GPU droplet
{ config, pkgs, pkgs-unstable, lib, ... }:

{
  imports = [
    ./disk-config.nix
    ./hardware.nix
    ./k3s.nix
    ./tailscale.nix
    ./networking.nix
  ];

  system.stateVersion = "24.11";
  time.timeZone = "America/New_York";

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      download-buffer-size = 500000000;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  environment.systemPackages = with pkgs; [
    # Core tools
    git
    curl
    wget
    vim
    htop
    jq
    tree

    # k8s tooling
    kubectl
    kubernetes-helm
    k9s

    # Secrets
    vault

    # Debugging
    dig
    iperf3
    openssl

    # GPU
    nvtopPackages.nvidia

    # Python (for core/ scripts)
    python3
  ];

  services.openssh.enable = true;

  # Allow the root user to use kubectl with k3s
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
}
