const net = require("net")

class BindProxy {

    constructor(lhost, lport, rhost, rport, verbose=true) {
        // Initialize TCP proxy
        this.lhost = lhost;
        this.lport = lport;
        this.rhost = rhost;
        this.rport = rport;
        this.data_size = 4096;
        this.verbose = verbose;
    }

    start() {
        const srv = this._bind();
        srv.listen(this.lport, this.lhost, 25, () => {
            if (this.verbose) {
                console.log(`Listening on ${this.lhost}:${this.lport}`);
            }
        });
        srv.on("error", (err) => {
            console.log(`Error: ${err.message}`);
        });
    }

    _connect(client_sock) {
        const s = new net.Socket();
        s.connect({ port: this.rport, host: this.rhost }, () => {
            if (this.verbose) {
                console.log(`Connected to remote host on ${this.rhost}:${this.rport}`);
            }
        });
        // Socket recv
        s.on("data", (data) => {
            client_sock.write(data);
        });
        // Socket close
        s.on("end", () => {
            client_sock.end();
        });
        return s;
    }

    _bind() {
        // Bind a TCP socket listener
        const server = net.createServer((client_sock) => {
            // Connect to the remote server
            const ip = client_sock.remoteAddress;
            const port = client_sock.remotePort;
            if (this.verbose){
                console.log(`Connection received from ${ip}:${port}`);
            }
            // Connect to remote server
            const server_sock = this._connect(client_sock);
            // Handle socket recv
            client_sock.on("data", (data) => {
                server_sock.write(data);
            });
            // Socket close
            client_sock.on("end", () => {
                server_sock.end();
                if (this.verbose) {
                    console.log(`Proxied connection closed!`);
                }
            });
        });
        return server;
    }

}

bndprx = new BindProxy("{{LHOST}}", {{LPORT}}, "{{RHOST}}", {{RPORT}});
bndprx.start();
