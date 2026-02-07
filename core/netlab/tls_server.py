"""
Layer 2: TLS Echo Server
=========================

WHAT THIS TEACHES:
- How TLS wraps a TCP connection
- The TLS handshake (what happens AFTER the TCP 3-way handshake, BEFORE app data)
- How certificates and private keys are used
- Server authentication: the client verifies the server's identity

THE TLS 1.3 HANDSHAKE (simplified):
  Client                              Server
    |                                    |
    |  --- ClientHello ----------------→ |  "I support these cipher suites, here's
    |      (supported ciphers,           |   my random nonce and key share"
    |       key share, SNI)              |
    |                                    |
    |  ←-- ServerHello + Certificate --- |  "Let's use this cipher. Here's my cert
    |      + CertificateVerify           |   and proof I own the private key"
    |      + Finished                    |
    |                                    |
    |  --- Finished -----------------→   |  "I verified your cert against my CA trust
    |                                    |   store. Handshake complete."
    |                                    |
    |  ←=== Encrypted app data ====→     |  All data is now encrypted with the
    |                                    |  negotiated symmetric key (AES-GCM etc.)

KEY INSIGHT:
  TLS uses ASYMMETRIC crypto (RSA/ECDSA) only for the handshake — to verify identity
  and exchange keys. The actual data is encrypted with SYMMETRIC crypto (AES-GCM),
  which is ~1000x faster. This is why TLS has negligible performance overhead.

OBSERVE IT LIVE:
  # Watch the handshake with openssl s_client:
  openssl s_client -connect localhost:9443 -CAfile certs/ca.crt -state -debug

  # Or with tcpdump (you'll see the handshake packets, but data is encrypted):
  sudo tcpdump -i lo -nn port 9443 -X
"""

import socket
import ssl
import threading
import os

CERT_DIR = os.path.join(os.path.dirname(__file__), "certs")


def handle_client(tls_socket: ssl.SSLSocket, address: tuple):
    """Handle a TLS-wrapped client connection."""
    # At this point, BOTH the TCP handshake AND TLS handshake are complete.
    # The tls_socket transparently encrypts/decrypts everything.
    print(f"[+] TLS connection from {address[0]}:{address[1]}")
    print(f"    Protocol: {tls_socket.version()}")
    print(f"    Cipher:   {tls_socket.cipher()[0]} ({tls_socket.cipher()[2]}-bit)")

    try:
        while True:
            # recv() here reads DECRYPTED data. Under the hood:
            #   1. Kernel receives encrypted TLS records from the network
            #   2. ssl module decrypts them using the session key
            #   3. Returns plaintext to your application
            #
            # An attacker sniffing the network sees only encrypted garbage.
            data = tls_socket.recv(4096)

            if not data:
                print(f"[-] {address[0]}:{address[1]} disconnected")
                break

            print(f"[<] Received (decrypted): {data.decode('utf-8', errors='replace')}")

            # sendall() encrypts the data before sending:
            #   1. ssl module encrypts plaintext → TLS record
            #   2. TLS record includes a MAC (message authentication code)
            #      so the receiver can verify the data wasn't tampered with
            #   3. Encrypted record sent over TCP
            tls_socket.sendall(data)
            print(f"[>] Echoed (encrypted on the wire)")

    except ssl.SSLError as e:
        print(f"[!] SSL error: {e}")
    except ConnectionResetError:
        print(f"[!] Connection reset by {address[0]}:{address[1]}")
    finally:
        tls_socket.close()


def main():
    # Step 1: Create a regular TCP socket (same as before)
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    # Step 2: Create an SSL context — this holds our TLS configuration
    #
    # PROTOCOL_TLS_SERVER = server-side TLS with automatic version negotiation.
    # The context holds:
    #   - Which TLS versions to allow (1.2, 1.3)
    #   - Which cipher suites to offer
    #   - Our certificate and private key
    #   - Whether to verify client certificates (mutual TLS)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)

    # Load our certificate chain:
    #   certfile = our server certificate (signed by our CA)
    #   keyfile  = our private key (proves we own the certificate)
    #
    # During the TLS handshake, the server sends the certificate to the client.
    # The client verifies: "Is this cert signed by a CA I trust?"
    context.load_cert_chain(
        certfile=os.path.join(CERT_DIR, "server.crt"),
        keyfile=os.path.join(CERT_DIR, "server.key"),
    )

    # Optional: set minimum TLS version (disable old, insecure versions)
    context.minimum_version = ssl.TLSVersion.TLSv1_2

    print(f"[*] Loaded certificate: {os.path.join(CERT_DIR, 'server.crt')}")
    print(f"[*] Loaded private key: {os.path.join(CERT_DIR, 'server.key')}")

    host = "0.0.0.0"
    port = 9443  # 443 is the standard HTTPS port; we use 9443 to avoid needing root
    server.bind((host, port))
    server.listen(5)
    print(f"[*] TLS Echo Server listening on {host}:{port}")
    print(f"[*] Try: python tls_client.py")
    print(f"[*] Or:  openssl s_client -connect localhost:{port} -CAfile certs/ca.crt")
    print(f"[*] Or:  curl --cacert certs/ca.crt https://localhost:{port}/")

    try:
        while True:
            # accept() returns a raw TCP socket (3-way handshake done)
            client_socket, address = server.accept()

            # wrap_socket() performs the TLS handshake on top of the TCP connection.
            # This is where the magic happens:
            #   1. Server sends its certificate
            #   2. Client verifies the cert (if it trusts our CA)
            #   3. They negotiate a cipher suite and exchange keys
            #   4. Returns an SSLSocket that encrypts/decrypts transparently
            #
            # If the handshake fails (client doesn't trust our CA, wrong hostname,
            # expired cert, etc.), this raises ssl.SSLError.
            try:
                tls_socket = context.wrap_socket(
                    client_socket,
                    server_side=True,
                )
            except ssl.SSLError as e:
                print(f"[!] TLS handshake failed from {address}: {e}")
                client_socket.close()
                continue

            thread = threading.Thread(
                target=handle_client,
                args=(tls_socket, address),
                daemon=True,
            )
            thread.start()
    except KeyboardInterrupt:
        print("\n[*] Shutting down")
    finally:
        server.close()


if __name__ == "__main__":
    main()
