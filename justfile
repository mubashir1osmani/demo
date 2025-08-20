#!/usr/bin/env -S just --justfile

default:
    @just --list

# Start all services via docker compose
start:
    docker compose up -d
    @echo "Services started - Open WebUI available at http://localhost:3000"

stop:
    docker compose down

logs:
    docker compose logs -f

logs-ollama:
    docker compose logs -f ollama

# Show just openwebui logs
logs-webui:
    docker compose logs -f openwebui

# Check the status of running services
status:
    docker compose ps
    @echo "\nOllama Models:"
    @docker compose exec -T ollama ollama list 2>/dev/null || echo "Ollama not running"

# Pull a model (usage: just pull-model llama3:8b)
pull-model MODEL:
    docker compose exec ollama ollama pull {{MODEL}}

# Reset everything (WARNING: Deletes all data)
reset:
    docker compose down -v
    @echo "All services and volumes have been removed"

# Generate a NixOS configuration file
generate-nixos-config:
    @echo "Generating NixOS configuration file..."
    cp nix/host.nix configuration.nix
    @echo "Configuration generated: configuration.nix"
    @echo "To deploy on NixOS: Copy to /etc/nixos/ and run 'sudo nixos-rebuild switch'"

# Install this service on NixOS (requires sudo)
install-nixos:
    @echo "Installing on NixOS..."
    sudo cp nix/host.nix /etc/nixos/ollama-config.nix
    @echo "import ./ollama-config.nix" | sudo tee -a /etc/nixos/configuration.nix >/dev/null
    @echo "Configuration installed. Run 'sudo nixos-rebuild switch' to apply."