"""
Layer 2: TLS Client
====================

WHAT THIS TEACHES:
- Client-side TLS: how YOUR code verifies the server's identity
- CA trust stores: why you need to load the CA certificate
- What happens when verification fails (and why that's a GOOD thing)
- SNI (Server Name Indication): how one IP can serve multiple TLS sites

TRUST MODEL:
  Your client has: ca.crt (the CA's public certificate)
  The server has:  server.crt (signed by the CA) + server.key (private)

  When connecting:
    1. Server presents server.crt
    2. Client extracts the CA signature from server.crt
    3. Client uses ca.crt's public key to verify that signature
    4. If valid → "This cert was genuinely signed by our CA" → trusted
    5. If invalid → SSLCertVerificationError → connection refused

  This is EXACTLY how your browser works, except it has ~150 pre-installed CA certs
  (from DigiCert, Let's Encrypt, etc.) instead of our single custom CA.

EXPERIMENTS TO TRY:
  1. Normal connection (works):
     python tls_client.py

  2. Without loading our CA (fails — "certificate verify failed"):
     # Edit this file, comment out context.load_verify_locations(...)
     # You'll see: ssl.SSLCertVerificationError

  3. Wrong hostname (fails — hostname mismatch):
     python tls_client.py 192.168.1.50
     # If 192.168.1.50 isn't in the cert's SANs, it fails

  4. Inspect the handshake with openssl:
     openssl s_client -connect localhost:9443 -CAfile certs/ca.crt -state
"""

import socket
import ssl
import sys
import os

CERT_DIR = os.path.join(os.path.dirname(__file__), "certs")


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else "localhost"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 9443

    # Step 1: Create SSL context for CLIENT side
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)

    # Step 2: Load our CA certificate into the trust store
    #
    # This tells the client: "I trust certificates signed by this CA."
    # Without this line, the client would reject the server's certificate
    # because it's signed by an unknown CA.
    #
    # In production, you'd either:
    #   - Use the system trust store: context.load_default_certs()
    #   - Or for internal services: load your organization's CA cert (like we do here)
    ca_cert = os.path.join(CERT_DIR, "ca.crt")
    context.load_verify_locations(ca_cert)
    print(f"[*] Loaded CA certificate: {ca_cert}")

    # Step 3: Create TCP socket and wrap with TLS
    raw_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # wrap_socket() with server_hostname enables TWO things:
    #   1. SNI (Server Name Indication) — sends the hostname in the ClientHello
    #      so the server can present the right certificate (important when one IP
    #      hosts multiple TLS sites, like nginx ingress does)
    #   2. Hostname verification — after the handshake, the client checks that
    #      the hostname matches one of the cert's SANs (Subject Alternative Names)
    tls_socket = context.wrap_socket(raw_socket, server_hostname=host)

    print(f"[*] Connecting to {host}:{port} with TLS...")
    try:
        tls_socket.connect((host, port))
    except ssl.SSLCertVerificationError as e:
        print(f"[!] Certificate verification FAILED: {e}")
        print(f"    This means the server's cert is not trusted by our CA,")
        print(f"    or the hostname doesn't match the cert's SANs.")
        sys.exit(1)
    except ConnectionRefusedError:
        print(f"[!] Connection refused — is the TLS server running on {host}:{port}?")
        sys.exit(1)

    # Connection established! Print TLS session details.
    print(f"[+] TLS connection established!")
    print(f"    Protocol: {tls_socket.version()}")
    print(f"    Cipher:   {tls_socket.cipher()[0]} ({tls_socket.cipher()[2]}-bit)")

    # Inspect the server's certificate
    cert = tls_socket.getpeercert()
    print(f"    Subject:  {dict(x[0] for x in cert['subject'])}")
    print(f"    Issuer:   {dict(x[0] for x in cert['issuer'])}")
    print(f"    Valid:    {cert['notBefore']} → {cert['notAfter']}")
    if "subjectAltName" in cert:
        sans = [v for _, v in cert["subjectAltName"]]
        print(f"    SANs:     {', '.join(sans)}")
    print()
    print("Type messages to send (Ctrl+C to quit):")

    try:
        while True:
            message = input("> ")
            if not message:
                continue

            # sendall/recv work identically to raw TCP — the encryption
            # is completely transparent. Your application code doesn't change.
            tls_socket.sendall(message.encode("utf-8"))
            print(f"[>] Sent {len(message)} bytes (encrypted on the wire)")

            data = tls_socket.recv(4096)
            if not data:
                print("[!] Server closed the connection")
                break
            print(f"[<] Received (decrypted): {data.decode('utf-8')}")

    except KeyboardInterrupt:
        print("\n[*] Closing TLS connection")
    finally:
        tls_socket.close()


if __name__ == "__main__":
    main()
