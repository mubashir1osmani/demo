# Layer 3: Containerize the TLS server for k8s deployment
#
# WHAT THIS TEACHES:
# - How a container packages an application + its dependencies
# - Multi-stage builds (keep the final image small)
# - How k8s pods run containers
#
# The TLS certs are NOT baked into the image — they're mounted as k8s Secrets.
# This is the correct pattern: images are public, secrets are injected at runtime.

FROM python:3.12-slim

WORKDIR /app

# No pip dependencies needed — we only use the stdlib (socket, ssl, threading)
COPY tcp_server.py tcp_client.py tls_server.py tls_client.py ./

# The server will listen on 9000 (TCP) and 9443 (TLS)
EXPOSE 9000 9443

# Default: run the TLS server
# Certs are expected at /app/certs/ (mounted via k8s Secret volume)
CMD ["python", "tls_server.py"]
