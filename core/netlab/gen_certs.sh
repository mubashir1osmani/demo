#!/usr/bin/env bash
#
# Generate a custom Certificate Authority + server certificate for TLS learning
# =============================================================================
#
# WHAT THIS TEACHES:
#   - How TLS certificate chains work (CA → server cert)
#   - What a Certificate Authority actually IS (just a key pair + self-signed cert)
#   - Why browsers/clients need to trust the CA, not each individual server cert
#   - The difference between a self-signed cert and a CA-signed cert
#
# THE CERTIFICATE CHAIN:
#   1. CA key pair     → ca.key (private, NEVER share) + ca.crt (public, distribute to clients)
#   2. Server key pair → server.key (private, stays on server) + server.csr (signing request)
#   3. CA signs the CSR → server.crt (CA vouches: "this cert belongs to this server")
#
# WHEN A TLS CLIENT CONNECTS:
#   1. Server sends server.crt
#   2. Client checks: "Is this cert signed by a CA I trust?"
#   3. Client has ca.crt in its trust store → signature checks out → connection trusted
#
# IN REAL LIFE:
#   - Let's Encrypt / DigiCert / etc. are CAs whose ca.crt ships with your OS/browser
#   - For internal services, you run your OWN CA (exactly what we're doing here)
#   - In k8s, cert-manager automates this (it runs a CA inside the cluster)
#
# USAGE:
#   chmod +x gen_certs.sh
#   ./gen_certs.sh
#   # Creates: certs/ca.key, certs/ca.crt, certs/server.key, certs/server.crt

set -euo pipefail
CERT_DIR="$(dirname "$0")/certs"
mkdir -p "$CERT_DIR"

echo "=== Step 1: Generate the Certificate Authority (CA) ==="
echo "This creates a private key and a self-signed certificate."
echo "The CA is the 'root of trust' — clients must trust this cert."
echo

# Generate CA private key (RSA 4096-bit)
# This is the secret that signs other certificates.
# In production, this key is stored in an HSM (hardware security module).
openssl genrsa -out "$CERT_DIR/ca.key" 4096
echo "  → ca.key created (4096-bit RSA private key)"

# Generate self-signed CA certificate
# -x509 = output a certificate (not a CSR)
# -new = generate a new certificate
# -days 3650 = valid for 10 years
# -subj = the Distinguished Name (DN) embedded in the cert
openssl req -x509 -new -nodes \
    -key "$CERT_DIR/ca.key" \
    -sha256 \
    -days 3650 \
    -out "$CERT_DIR/ca.crt" \
    -subj "/C=US/ST=Lab/O=AI Lab CA/CN=AI Lab Root CA"
echo "  → ca.crt created (self-signed CA certificate)"
echo

echo "=== Step 2: Generate the server key + Certificate Signing Request (CSR) ==="
echo "The CSR is a 'please sign this' request sent to the CA."
echo "It contains the server's public key + identity info, but NOT the CA's signature yet."
echo

# Generate server private key
openssl genrsa -out "$CERT_DIR/server.key" 2048
echo "  → server.key created (2048-bit RSA private key)"

# Create a config file for the CSR with Subject Alternative Names (SANs)
# SANs are CRITICAL — modern TLS clients check SANs, not the CN (Common Name).
# Without the right SANs, you'll get "certificate does not match hostname" errors.
cat > "$CERT_DIR/server.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = dn
req_extensions = v3_req

[dn]
C = US
ST = Lab
O = AI Lab
CN = netlab.ai-lab.svc.cluster.local

[v3_req]
subjectAltName = @alt_names

[alt_names]
# These are all the hostnames this cert is valid for:
DNS.1 = localhost
DNS.2 = netlab
DNS.3 = netlab.ai-lab.svc.cluster.local
DNS.4 = netlab.gpu-lab.tail1234.ts.net
IP.1 = 127.0.0.1
IP.2 = 0.0.0.0
EOF

# Generate the CSR
openssl req -new \
    -key "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.csr" \
    -config "$CERT_DIR/server.cnf"
echo "  → server.csr created (certificate signing request)"
echo

echo "=== Step 3: CA signs the server certificate ==="
echo "The CA uses its private key to sign the CSR, producing the final server cert."
echo "This is the equivalent of Let's Encrypt issuing you a cert."
echo

openssl x509 -req \
    -in "$CERT_DIR/server.csr" \
    -CA "$CERT_DIR/ca.crt" \
    -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERT_DIR/server.crt" \
    -days 365 \
    -sha256 \
    -extensions v3_req \
    -extfile "$CERT_DIR/server.cnf"
echo "  → server.crt created (CA-signed server certificate, valid 365 days)"
echo

echo "=== Step 4: Verify the chain ==="
openssl verify -CAfile "$CERT_DIR/ca.crt" "$CERT_DIR/server.crt"
echo

echo "=== Inspect the server certificate ==="
echo "Look for: Issuer (should be our CA), Subject, SANs, validity dates"
openssl x509 -in "$CERT_DIR/server.crt" -text -noout | head -30
echo

echo "=== Done! ==="
echo "Files created in $CERT_DIR/:"
ls -la "$CERT_DIR"
echo
echo "Next steps:"
echo "  1. Run the TLS server:  python tls_server.py"
echo "  2. Connect with client: python tls_client.py"
echo "  3. Or use openssl:      openssl s_client -connect localhost:9443 -CAfile certs/ca.crt"
echo "  4. Or use curl:         curl --cacert certs/ca.crt https://localhost:9443/"
