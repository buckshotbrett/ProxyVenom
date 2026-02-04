const net = require("net")

class ReverseProxy {

    constructor(chost, cport, rhost, rport, verbose=true) {
        // Initialize TCP proxy
        this.chost = chost;
        this.cport = cport;
        this.rhost = rhost;
        this.rport = rport;
        this.data_size = 4096;
        this.verbose = verbose;
        this.header_length = 5;
    }

    start() {
        var server_sock;
        const client_sock = this._connect(this.chost, this.cport, "Proxy connected to client.");
        client_sock.on("readable", () => {
            let header;
            let msg;
            // Read header
            while ((header = client_sock.read(this.header_length)) !== null) {
                var cmd = header.readUInt8(0);
                var data_len = header.readInt32BE(1);
                if (cmd == 0) { // Read data
                    if (server_sock) {
                        while ((msg = client_sock.read(data_len)) !== null) {
                            server_sock.write(msg);
                            break;
                        }
                    }
                }
                else if (cmd == 1) {
                    // Connect to remote host
                    server_sock = this._connect(this.rhost, this.rport, "Proxy connected to remote host.");
                    server_sock.on("data", (data) => {
                        this._send_all(client_sock, 0, data);
                    });
                    server_sock.on("end", () => {
                        if (this.verbose) {
                            console.log("Proxy disconnected from remote host.");
                        }
                        this._send_all(client_sock, 2, null);
                        server_sock = null;
                    });
                }
                else if (cmd == 2) { // Close socket
                    if (server_sock) {
                        server_sock.end();
                    }
                }
            }
        });
    }

    _send_all(sock, c, data) {
        let hdr = Buffer.alloc(this.header_length);
        if (data != null) {
            var data_len = data.length;
        }
        else {
            var data_len = 0;
        }
        hdr.writeUInt8(c, 0);
        hdr.writeUInt32BE(data_len, 1);
        sock.write(hdr);
        if (data !== null) {
            sock.write(data);
        }
    }

    _connect(remote_host, remote_port, msg) {
        var s = new net.Socket();
        s.connect({ port: remote_port, host: remote_host }, () => {
            if (this.verbose) {
                console.log(msg);
            }
        });
        return s;
    }

}

revprx = new ReverseProxy("{{CHOST}}", {{CPORT}}, "{{RHOST}}", {{RPORT}});
revprx.start();
