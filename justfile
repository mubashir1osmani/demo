install-nixos:
    sudo nixos-rebuild switch --flake ./nix#nix-demo

install-packages:
    sudo nixos-rebuild switch --flake ./nix#nix-demo

install-litellm:
    echo "⬇️  Pulling litellm Docker image..."
    docker pull ghcr.io/berriai/litellm:main-stable
    echo "litellm image pulled"

up:
    just start-local

down:
    cd ansible/services && docker compose down

restart: down up

status:
    cd ansible/services && docker compose ps

test-litellm:
    curl -s -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" http://localhost:4000/v1/models | jq '.data[].id' || echo "Failed to get models!"

start-proxy:
    cd ansible/services && docker compose --env-file ../../.env up -d litellm
    echo "proxy server started @ http://localhost:4000"

start-openwebui:
    cd ansible/services && docker compose --env-file ../../.env up -d openwebui
    echo "openwebui running @ http://localhost:3000"

start-local: 
    just install-litellm
    just start-proxy
    just start-openwebui
    just status

# Database management commands
start-databases:
    cd ansible/services && docker compose --env-file ../../.env up -d neo4j

db-neo4j:
    docker exec -it graph-db cypher-shell -u neo4j -p secret
