{ pkgs, unstablePkgs, lib, inputs, ... }:
let
  inherit (inputs) nixpkgs nixpkgs-unstable;
in

{
  time.timeZone = "America/New_York";
  system.stateVersion = "24.11";

  environment.systemPackages = with pkgs; [
    tailscale
    curl
    wget
    docker
    docker-compose
    postgresql
    cypher-shell
    jq
  ];

  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };

  services.tailscale = {
    enable = true;
    authKeyFile = "/var/lib/tailscale/authkey";
    useRoutingFeatures = "both";
  };

  nix = {
    settings = {
        experimental-features = [ "nix-command" "flakes" ];
        warn-dirty = false;
        # 500mb buffer
        download-buffer-size = 500000000;
    };
    # Automate garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 5";
    };
  };

  networking = {
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts = [ 3000 4000 5432 7474 7687 ];
    };
    dns = {
      servers = [ "100.100.100.100" ];
      search = [ "tailnet-name.ts.net" ];
    };
    hostName = "nix-demo";
  };

  services.openssh.enable = true;
}