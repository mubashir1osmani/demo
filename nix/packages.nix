{ pkgs ? import <nixpkgs> {} }:

let
  ollama-custom = pkgs.ollama.overrideAttrs (oldAttrs: {
  });
  
  pull-ai-model = pkgs.writeShellScriptBin "pull-ai-model" ''
    if [ -z "$1" ]; then
      echo "Usage: pull-ai-model <model-name>"
      echo "Example: pull-ai-model llama3:8b"
      exit 1
    fi
    
    echo "Pulling model $1..."
    ${pkgs.ollama}/bin/ollama pull "$1"
  '';
  
  manage-openwebui = pkgs.writeShellScriptBin "manage-openwebui" ''
    case "$1" in
      start)
        systemctl start openwebui
        ;;
      stop)
        systemctl stop openwebui
        ;;
      restart)
        systemctl restart openwebui
        ;;
      logs)
        journalctl -u openwebui -f
        ;;
      *)
        echo "Usage: manage-openwebui [start|stop|restart|logs]"
        ;;
    esac
  '';
  
in {
  inherit ollama-custom check-ai-services pull-ai-model manage-openwebui;
  
  # Create a convenient environment with all tools
  environment = pkgs.buildEnv {
    name = "ai-tools-env";
    paths = [
      ollama-custom
      pull-ai-model
      manage-openwebui
      pkgs.tailscale
      pkgs.docker-compose
    ];
  };
}