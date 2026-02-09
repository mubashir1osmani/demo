# Networking & Firewall
# Only Tailscale interface is trusted — public internet gets nothing except SSH
{ config, pkgs, lib, ... }:

{
  networking = {
    hostName = "gpu-lab";

    firewall = {
      enable = true;
      # Only allow SSH from the public internet
      allowedTCPPorts = [ 22 ];
      # Trust the Tailscale interface — all k8s service ports are accessible here
      trustedInterfaces = [ "tailscale0" ];
    };

    nameservers = [ "100.100.100.100" ];
    search = [ "tail1234.ts.net" ];
  };
}
