# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Private AI Lab infrastructure running on a **Digital Ocean GPU droplet** with **NixOS**, **k3s** (lightweight Kubernetes), **Nginx ingress**, and **Tailscale** for private networking. The stack provides a unified LLM gateway via **LiteLLM**, a chat frontend via **Open WebUI**, and local GPU inference via **Ollama** and **vLLM**.

## Architecture

```
Tailnet (private)
    |
  Nginx Ingress (k3s, binds to Tailscale IP)
    |
    ├── Open WebUI (:8080)   — chat frontend, connects to LiteLLM
    ├── LiteLLM (:4000)      — LLM proxy/gateway, routes to all providers
    ├── Phoenix (:6006)      — self-hosted observability (OTLP traces)
    └── Grafana (:3000)      — Prometheus dashboards

  Internal (ClusterIP only):
    ├── PostgreSQL (:5432)   — LiteLLM state, audit logs
    ├── Neo4j (:7474/:7687)  — document/graph storage
    ├── Ollama (:11434)      — local model serving (GPU)
    ├── vLLM (:8000)         — high-perf inference (GPU)
    ├── SearXNG (:8080)      — web search for RAG
    └── Prometheus (:9090)   — metrics collection
```

## Directory Structure

- **nix/** — NixOS flake. `nix/hosts/gpu-lab/` has modular configs: `default.nix` (main), `hardware.nix` (NVIDIA/GPU), `k3s.nix`, `tailscale.nix`, `networking.nix`.
- **k8s/** — Kubernetes manifests for all services. Each service has its own directory with deployment, service, and optionally ingress/configmap YAMLs.
- **ansible/** — Deployment automation. `playbooks/provision.yml` syncs NixOS config and rebuilds, `playbooks/deploy.yml` applies k8s manifests and Helm charts, `playbooks/secrets.yml` creates k8s secrets from `.env`.
- **gateway/** — `litellm-config.yml` defines all model routes, callbacks, and settings. Mounted as a ConfigMap in k8s.
- **core/** — Python scripts: `traces.py` (Phoenix OpenTelemetry), `ocr.py` (DeepSeek-OCR via vLLM), `db/` (Neo4j Cypher schemas).

## Commands

### Provision the server (NixOS rebuild)
```bash
ansible-playbook -i ansible/inventory.ini ansible/playbooks/provision.yml --extra-vars "tailscale_auth_key=YOUR_KEY"
```

### Create k8s secrets from .env
```bash
ansible-playbook -i ansible/inventory.ini ansible/playbooks/secrets.yml
```

### Deploy all services
```bash
ansible-playbook -i ansible/inventory.ini ansible/playbooks/deploy.yml
```

### On the server directly
```bash
# Rebuild NixOS
sudo nixos-rebuild switch --flake /etc/nixos#gpu-lab

# k8s commands
kubectl get pods -n ai-lab
kubectl logs -n ai-lab deploy/litellm
kubectl exec -n ai-lab deploy/ollama -- ollama pull llama3.1:8b
```

## Key Configuration Files

- `gateway/litellm-config.yml` — Model routing, callbacks, general settings. Mounted as k8s ConfigMap.
- `.env` — All API keys and secrets (never committed — use `.env.example` as template).
- `k8s/litellm/deployment.yml` — LiteLLM pod spec with all env var references to secrets.
- `k8s/ingress/nginx-values.yml` — Nginx ingress Helm values (binds to Tailscale IP).
- `nix/hosts/gpu-lab/` — NixOS modules for the GPU droplet.

## Important Notes

- **All services are private** — only accessible via Tailscale. The firewall allows only SSH (port 22) from the public internet.
- LiteLLM model names use `provider/model-id` in `litellm_params.model`; `model_name` is the user-facing alias.
- Ollama and vLLM are **internal-only** (ClusterIP) — accessed via LiteLLM, not directly.
- GPU sharing: Ollama and vLLM each request `nvidia.com/gpu: 1`. On a single-GPU droplet, only run one at a time (scale the other to 0 replicas).
- Phoenix is self-hosted (not cloud SaaS). LiteLLM sends OTLP traces to `phoenix.ai-lab.svc.cluster.local:4317`.
- k3s uses `--disable traefik` — Nginx Ingress is installed via Helm instead.
- Ingress hostnames follow the pattern `<service>.gpu-lab.<tailnet>.ts.net`. Replace `tail1234` in ingress YAMLs with your actual tailnet domain.
