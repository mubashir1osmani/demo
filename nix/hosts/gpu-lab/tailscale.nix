{ config, pkgs, lib, ... }:

{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/lib/tailscale/authkey";
    useRoutingFeatures = "both";
  };

  # Ensure the tailscale state directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/tailscale 0700 root root -"
  ];
}
