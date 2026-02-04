class BindProxy {
    private $lhost;
    private $lport;
    private $rhost;
    private $rport;
    private $data_size;
    private $verbose;

    public function __construct($lhost, $lport, $rhost, $rport, $verbose=true) {
        $this->lhost = $lhost;
        $this->lport = $lport;
        $this->rhost = $rhost;
        $this->rport = $rport;
        $this->verbose = $verbose;
        $this->data_size = 4096;
    }

    public function start() {
        # Start proxy
        $s = $this->_bind();
        if ($s) {
            socket_listen($s, 25);
            if ($this->verbose) {
                echo "Listening on {$this->lhost}:{$this->lport}\n";
            }
            while (true) {
                try {
                    $conn = socket_accept($s);
                    if ($this->verbose) {
                        socket_getpeername($conn, $ip, $port);
                        echo "Connection received from {$ip}:{$port}\n";
                    }
                    $this->_switch($conn);
                }
                catch (Excception $e) {
                    break;
                }
            }
        }
    }

    private function _switch($client_sock) {
        # Switch between read/write
        $server_sock = $this->_connect();
        if ($client_sock and $server_sock) {
            socket_set_nonblock($client_sock);
            socket_set_nonblock($server_sock);
            $client_read = true;
            while (true) {
                # Recv from client
                if ($client_read) {
                    $data = "";
                    $bytes_received = socket_recv($client_sock, $data, $this->data_size, 0);
                    if ($bytes_received === false) {
                        $error_code = socket_last_error($client_sock);
                        if ($error_code == SOCKET_EAGAIN || $error_code == SOCKET_EWOULDBLOCK) {
                            $client_read = false;
                            usleep(5000);
                        }
                        else {
                            break;
                        }
                    }
                    elseif ($bytes_received === 0) {
                        # Client gracefully closed the connection
                        break;
                    }
                    else {
                        $this->_socket_sendall($server_sock, $data);
                    }
                }
                # Recv from server
                if (!$client_read) {
                    $data = "";
                    $bytes_received = socket_recv($server_sock, $data, $this->data_size, 0);
                    if ($bytes_received === false) {
                        $error_code = socket_last_error($server_sock);
                        if ($error_code == SOCKET_EAGAIN || $error_code == SOCKET_EWOULDBLOCK) {
                            $client_read = true;
                            usleep(5000);
                        }
                        else {
                            break;
                        }
                    }
                    elseif ($bytes_received === 0) {
                        # Server gracefully closed the connection
                        break;
                    }
                    else {
                        $this->_socket_sendall($client_sock, $data);
                    }
                }
            }
            # Close the sockets if any are still open
            $this->_close($client_sock, $server_sock);
        }
    }

    private function _socket_sendall($sock, $data) {
        $bytes_sent = 0;
        $total_bytes = strlen($data);
        while ($bytes_sent < $total_bytes) {
            $sent = socket_write($sock, substr($data, $bytes_sent), $total_bytes - $bytes_sent);
            $bytes_sent += $sent;
        }
    }

    private function _close($client, $server) {
        # Close client and server sockets
        # Close client
        try {
            socket_close($client);
        }
        catch (Exception $e) {}
        # Close server
        try {
            socket_close($server);
        }
        catch (Exception $e) {}
        if ($this->verbose) {
            echo "Proxied connection closed!\n";
        }
    }

    private function _connect() {
        # Connect to the server
        try {
            $s = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
            # Set indefinite timeouts
            socket_set_option($s, SOL_SOCKET, SO_RCVTIMEO, ['sec' => 0, 'usec' => 0]);
            socket_set_option($s, SOL_SOCKET, SO_SNDTIMEO, ['sec' => 0, 'usec' => 0]);
            $result = socket_connect($s, $this->rhost, $this->rport);
            if ($result) {
                if ($this->verbose) {
                    echo "Connected to remote host on {$this->rhost}:{$this->rport}\n";
                }
                return $s;
            }
            else {
                return NULL;
            }
        }
        catch (Exception $e) {
            return NULL;
        }
    }

    private function _bind() {
        # Bind a TCP socket listener
        try {
            $s = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
            socket_set_option($s, SOL_SOCKET, SO_REUSEADDR, 1);
            socket_bind($s, $this->lhost, $this->lport);
            return $s;
        }
        catch (Exception $e) {
            return NULL;
        }
    }

}

$bndprx = new BindProxy("{{LHOST}}", {{LPORT}}, "{{RHOST}}", {{RPORT}});
$bndprx->start();
