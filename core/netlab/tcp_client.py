"""
Layer 1: Raw TCP Client
========================

WHAT THIS TEACHES:
- The client side of a TCP connection
- connect() triggers the 3-way handshake
- How to observe the full packet exchange

PACKET FLOW when you run this:
  1. connect()     → Client kernel sends SYN to server
  2.               ← Server kernel responds with SYN-ACK
  3.               → Client kernel sends ACK (connect() returns)
  4. send()        → Client sends data in a PSH-ACK packet
  5.               ← Server echoes data back (PSH-ACK)
  6. close()       → Client sends FIN
  7.               ← Server sends ACK, then its own FIN
  8.               → Client sends final ACK

The "PSH" (push) flag tells the receiver's kernel to immediately deliver
the data to the application, rather than buffering it.
"""

import socket
import sys


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 9000

    # Create the socket (same as server — AF_INET + SOCK_STREAM = TCP over IPv4)
    client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # connect() does THREE things:
    #   1. Kernel picks a random ephemeral port (e.g., 52431) as the source port
    #   2. Sends SYN packet to (host, port)
    #   3. Blocks until SYN-ACK comes back and we send our ACK
    #
    # If the server isn't listening → "Connection refused" (kernel sends RST back)
    # If the server is unreachable → "Connection timed out" (SYN retries exhaust)
    print(f"[*] Connecting to {host}:{port}...")
    try:
        client.connect((host, port))
    except ConnectionRefusedError:
        print(f"[!] Connection refused — is the server running on {host}:{port}?")
        sys.exit(1)

    print(f"[+] Connected! Local address: {client.getsockname()}")
    print(f"    Remote address: {client.getpeername()}")
    print(f"    This connection is uniquely identified by the 4-tuple:")
    print(f"    ({client.getsockname()[0]}, {client.getsockname()[1]}, "
          f"{client.getpeername()[0]}, {client.getpeername()[1]})")
    print()
    print("Type messages to send (Ctrl+C to quit):")

    try:
        while True:
            message = input("> ")
            if not message:
                continue

            # send() copies bytes into the kernel's TCP send buffer.
            # The kernel then:
            #   1. Segments the data into MSS-sized chunks (typically 1460 bytes for ethernet)
            #   2. Adds TCP header (src_port, dst_port, seq, ack, flags, window, checksum)
            #   3. Passes to IP layer (adds IP header: src_ip, dst_ip, TTL, protocol=TCP)
            #   4. Passes to link layer (adds ethernet frame: src_mac, dst_mac)
            #   5. NIC transmits the frame
            #
            # sendall() ensures ALL bytes are sent (send() might only send partial data
            # if the kernel buffer is full — sendall retries until everything is sent).
            client.sendall(message.encode("utf-8"))
            print(f"[>] Sent {len(message)} bytes")

            # Wait for the echo response
            data = client.recv(4096)
            if not data:
                print("[!] Server closed the connection")
                break

            print(f"[<] Received: {data.decode('utf-8')}")

    except KeyboardInterrupt:
        print("\n[*] Closing connection")
    finally:
        # close() triggers the TCP connection teardown:
        #   Client → FIN → Server
        #   Server → ACK → Client
        #   Server → FIN → Client  (server also closes)
        #   Client → ACK → Server
        #
        # After this, the client socket enters TIME_WAIT for ~60 seconds.
        client.close()


if __name__ == "__main__":
    main()
