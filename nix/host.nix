{ config, pkgs, ... }:
{
    # System packages needed for our AI infrastructure
  environment.systemPackages = with pkgs; [
    # Networking tools
    tailscale
    curl
    wget
    
    # Docker-related tools
    docker-client
    docker-compose
    
    # Neo4j tools
    cypher-shell
  ];

  # Enable Tailscale service
  services.tailscale = {
    enable = true;
    # Set up Tailscale to automatically re-authenticate
    authKeyFile = "/var/lib/tailscale/authkey";
    # Allow this node to serve as an exit node if needed
    useRoutingFeatures = "both";
  };

  # Enable Docker service
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Create a dedicated service for Ollama
  systemd.services.ollama = {
    description = "Ollama AI model service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      ExecStart = "${pkgs.ollama}/bin/ollama serve";
      Restart = "always";
      RestartSec = "10s";
      User = "ollama";
      Group = "ollama";
      
      # Security hardening
      CapabilityBoundingSet = "";
      DevicePolicy = "closed";
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      ProtectClock = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      StateDirectory = "ollama";
      SystemCallArchitectures = "native";
    };
  };

  # Create a service for OpenWebUI
  systemd.services.openwebui = {
    description = "OpenWebUI service";
    after = [ "network.target" "ollama.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      ExecStart = ''
        ${pkgs.docker}/bin/docker run --rm \
          --name openwebui \
          -p 3000:8080 \
          -e OLLAMA_BASE_URL=http://localhost:11434 \
          -v openwebui_data:/app/backend/data \
          ghcr.io/open-webui/open-webui:main
      '';
      ExecStop = "${pkgs.docker}/bin/docker stop openwebui";
      Restart = "always";
      RestartSec = "10s";
      User = "root";  # Needed for Docker
    };
  };

  # Enable Neo4j service
  services.neo4j = {
    enable = true;
    
    # Set Neo4j options
    settings = {
      dbms.memory.heap.initial_size = "1G";
      dbms.memory.heap.max_size = "2G";
      dbms.security.auth_enabled = true;
      # Allow connections from any host (restrict with firewall)
      dbms.default_listen_address = "0.0.0.0";
      # Set default password (change this!)
      dbms.security.auth_minimum_password_length = 4;
    };
  };
  
  # Create the ollama user
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    description = "Ollama service user";
    home = "/var/lib/ollama";
    createHome = true;
  };
  
  users.groups.ollama = {};

  # Configure networking
  networking = {
    # Configure firewall
    firewall = {
      enable = true;
      # Allow Tailscale traffic
      trustedInterfaces = [ "tailscale0" ];
      # Allow OpenWebUI, Ollama, and Neo4j to be accessible
      allowedTCPPorts = [ 3000 11434 7474 7687 ];
    };
    
    # Use Tailscale DNS if available
    nameservers = [ "100.100.100.100" ];
    search = [ "tailnet-name.ts.net" ];  # Replace with your Tailnet name
  };

  # Configure hostname based on machine
  networking.hostName = "ai-server";

  # Enable the OpenSSH server
  services.openssh.enable = true;

  # Set your time zone
  time.timeZone = "America/New_York";  # Change to your timezone
}