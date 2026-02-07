"""
Layer 1: Raw TCP Echo Server
=============================

WHAT THIS TEACHES:
- How TCP sockets work at the system call level
- The TCP 3-way handshake (SYN → SYN-ACK → ACK)
- Connection lifecycle: bind → listen → accept → recv/send → close
- What happens at each step in terms of actual network packets

HOW TCP WORKS (the 3-way handshake):
  Client                    Server
    |  ---- SYN (seq=100) --->  |   "I want to connect, my starting sequence is 100"
    |  <-- SYN-ACK (seq=300, ---|   "OK, my starting sequence is 300, I ACK your 100"
    |       ack=101)            |
    |  ---- ACK (ack=301) ---> |    "Got it, I ACK your 300"
    |                           |   ← Connection established! Data can flow.

WHY SEQUENCE NUMBERS?
  TCP is a *reliable, ordered* byte stream. Sequence numbers let the receiver:
  1. Reassemble out-of-order packets
  2. Detect missing packets and request retransmission
  3. Discard duplicates

OBSERVE IT LIVE:
  # Terminal 1: start the server
  python tcp_server.py

  # Terminal 2: watch the packets (on the server machine)
  sudo tcpdump -i lo -nn port 9000 -X

  # Terminal 3: connect with the client
  python tcp_client.py

  You'll see the SYN, SYN-ACK, ACK, then your data packets, then FIN to close.
"""

import socket
import threading


def handle_client(client_socket: socket.socket, address: tuple):
    """
    Handle a single client connection.

    At this point, the 3-way handshake is ALREADY COMPLETE.
    accept() only returns after the kernel finishes SYN → SYN-ACK → ACK.

    The client_socket is a NEW socket, separate from the listening socket.
    This is how one server can handle many clients — each gets its own socket
    (identified by the 4-tuple: src_ip, src_port, dst_ip, dst_port).
    """
    print(f"[+] Connection from {address[0]}:{address[1]}")

    try:
        while True:
            # recv() is a BLOCKING call. It waits until:
            #   1. Data arrives (returns the bytes)
            #   2. Client sends FIN (returns empty bytes b'')
            #   3. Connection resets (raises an exception)
            #
            # The 4096 is the BUFFER SIZE — max bytes to read at once.
            # TCP is a BYTE STREAM, not a message protocol. A single send()
            # might arrive as multiple recv() calls, or multiple send() calls
            # might arrive in a single recv(). There are NO message boundaries.
            data = client_socket.recv(4096)

            if not data:
                # Empty bytes = client closed the connection (sent FIN).
                # The kernel does a 4-way close: FIN → ACK, FIN → ACK
                print(f"[-] {address[0]}:{address[1]} disconnected")
                break

            print(f"[<] Received {len(data)} bytes from {address[0]}:{address[1]}")
            print(f"    Hex: {data.hex()}")
            print(f"    Str: {data.decode('utf-8', errors='replace')}")

            # Echo it back — send() pushes bytes into the kernel's send buffer.
            # The kernel handles segmentation (breaking into MSS-sized chunks),
            # retransmission, flow control (TCP window), and congestion control.
            client_socket.sendall(data)
            print(f"[>] Echoed {len(data)} bytes back")

    except ConnectionResetError:
        # Client crashed or sent RST (reset) instead of a clean FIN close
        print(f"[!] Connection reset by {address[0]}:{address[1]}")
    finally:
        client_socket.close()


def main():
    # AF_INET  = IPv4 (vs AF_INET6 for IPv6)
    # SOCK_STREAM = TCP (vs SOCK_DGRAM for UDP)
    #
    # This creates a socket FILE DESCRIPTOR in the kernel.
    # At this point, it's not bound to any address yet.
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # SO_REUSEADDR lets us restart the server immediately after stopping it.
    # Without this, you'd get "Address already in use" for ~60 seconds because
    # the kernel keeps the socket in TIME_WAIT state after close.
    #
    # TIME_WAIT exists to handle delayed packets from the old connection —
    # without it, a delayed packet could arrive at a NEW connection on the
    # same port and corrupt its data stream.
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    # bind() tells the kernel: "I want to receive packets sent to this address:port"
    #
    # "0.0.0.0" means ALL interfaces. If you used "127.0.0.1" instead, the
    # server would ONLY accept connections from localhost. In k8s, pods use
    # "0.0.0.0" so the service can reach them on the pod's cluster IP.
    host = "0.0.0.0"
    port = 9000
    server.bind((host, port))

    # listen() marks the socket as PASSIVE — it will accept incoming connections
    # rather than initiate outgoing ones.
    #
    # The argument (5) is the BACKLOG — how many completed connections can wait
    # in the accept queue before the kernel starts dropping SYN packets.
    # Under the hood, there are actually TWO queues:
    #   1. SYN queue — connections mid-handshake (got SYN, sent SYN-ACK, waiting for ACK)
    #   2. Accept queue — fully established connections waiting for accept()
    server.listen(5)
    print(f"[*] TCP Echo Server listening on {host}:{port}")
    print(f"[*] Try: python tcp_client.py")
    print(f"[*] Or:  nc localhost {port}")
    print(f"[*] Watch packets: sudo tcpdump -i lo -nn port {port}")

    try:
        while True:
            # accept() blocks until a client completes the 3-way handshake.
            # Returns a NEW socket for this specific connection + the client's address.
            client_socket, address = server.accept()

            # Spawn a thread per connection. This is the simplest concurrency model.
            # Production servers use: select/poll/epoll (event loop), or async/await.
            thread = threading.Thread(
                target=handle_client,
                args=(client_socket, address),
                daemon=True,
            )
            thread.start()
    except KeyboardInterrupt:
        print("\n[*] Shutting down")
    finally:
        server.close()


if __name__ == "__main__":
    main()
