# Ansible Playbooks for Homelab Deployment

This directory contains Ansible playbooks to provision a server and deploy the homelab stack.

## Prerequisites

- A Debian-based server (e.g., Ubuntu 22.04 on Digital Ocean).
- Your server's IP address added to an Ansible inventory file (e.g., `inventory.ini`).
- Ansible installed on your local machine.

## Usage

### 1. Provision the Server

This playbook installs Docker, Docker Compose, and Tailscale on your server. It also joins the server to your Tailscale network.

```bash
ansible-playbook -i inventory.ini playbooks/provision.yml --ask-become-pass --extra-vars "tailscale_auth_key=YOUR_TAILSCALE_AUTH_KEY"
```

Replace `YOUR_TAILSCALE_AUTH_KEY` with a valid Tailscale authentication key.

### 2. Deploy the Application Stack

This playbook deploys the `litellm`, `openwebui`, `caddy`, and database containers. It will prompt you for the necessary secrets and configuration values.

```bash
ansible-playbook -i inventory.ini playbooks/deploy.yml --ask-become-pass
```

After running this playbook, your services will be accessible via their Tailscale MagicDNS names:

- **OpenWebUI:** `https://openwebui.homelab.your-tailnet.ts.net`
- **LiteLLM:** `https://litellm.homelab.your-tailnet.ts.net`