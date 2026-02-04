class ReverseProxy {
    private $chost;
    private $cport;
    private $rhost;
    private $rport;
    private $data_size;
    private $verbose;

    public function __construct($chost, $cport, $rhost, $rport, $verbose=true) {
        $this->chost = $chost;
        $this->cport = $cport;
        $this->rhost = $rhost;
        $this->rport = $rport;
        $this->verbose = $verbose;
        $this->data_size = 4096;
    }

    public function start() {
        # Start proxy
        $client_sock = $this->_connect($this->chost, $this->cport);
        if ($client_sock) {
            if ($this->verbose) {
                echo("Proxy connected to client.\n");
            }
            while (true) {
                $header = $this->_recv_all($client_sock, 5);
                if ($header) {
                    $hdr_vals = unpack("Ccmd/Ndlen", $header);
                    if ($hdr_vals === false) {
                        break;
                    }
                    $cmd = $hdr_vals["cmd"];
                    $data_len = $hdr_vals["dlen"];
                    # connect to remote host
                    if ($cmd == 1) {
                        $server_sock = $this->_connect($this->rhost, $this->rport);
                        if ($this->verbose) {
                            echo("Proxy connected to remote host.\n");
                        }
                        $this->_switch($client_sock, $server_sock);
                        $this->_close($server_sock);
                        if ($this->verbose) {
                            echo("Proxy disconnected from remote host.\n");
                        }
                    }
                }
                else {
                    usleep(5000);
                }
            }
            # Close other end
            $this->_sendall($client_sock, 2, "");
            $this->_close($client_sock);
        }
    }

    private function _switch($client_sock, $server_sock) {
        $server_closed = false;
        if ($client_sock && $server_sock) {
            # Switching toggle
            $client_read = true;
            while (true) {
                # recv from client
                if ($client_read) {
                    $header = $this->_recv_all($client_sock, 5);
                    if ($header === 1) { # error
                        break;
                    }
                    elseif ($header === 0) { # no data
                        $client_read = false;
                        usleep(5000);
                    }
                    elseif (strlen($header) == 5) { # Data received
                        $hdr_vals = unpack("Ccmd/Ndlen", $header);
                        $cmd = $hdr_vals["cmd"];
                        $data_len = $hdr_vals["dlen"];
                        if ($cmd == 0) {
                            $data = $this->_recv_all($client_sock, $data_len);
                            if (!$server_closed) {
                                $success = $this->_sendall($server_sock, $data);
                                if ($success === false) {
                                    $server_closed = true;
                                    $client_read = false;
                                    usleep(5000);
                                }
                            }
                            else {
                                $client_read = false;
                                usleep(5000);
                            }
                        }
                        elseif ($cmd == 2) { # close socket
                            break;
                        }
                    }
                }
                # recv from server
                if (!$client_read) {
                    $data = "";
                    $bytes_received = socket_recv($server_sock, $data, $this->data_size, 0);
                    if ($bytes_received === false) {
                        $error_code = socket_last_error($server_sock);
                        # No data
                        if ($error_code == SOCKET_EAGAIN || $error_code == SOCKET_EWOULDBLOCK) {
                            $client_read = true;
                            usleep(5000);
                        }
                        # Error
                        else {
                            $this->_send_all($client_sock, 2, "");
                            break;
                        }
                    }
                    elseif ($bytes_received === 0) {
                        # Server gracefully closed the connection
                        if ($server_closed) {
                            $this->_send_all($client_sock, 2, "");
                            break;
                        }
                        $server_closed = true;
                        $client_read = true;
                        usleep(5000);
                    }
                    else {
                        $success = $this->_send_all($client_sock, 0, $data);
                        if ($success === false) {
                            break;
                        }
                    }
                }
            }
        }
    }

    private function _sendall($sock, $data) {
        # Normal socket sendall function to block until all is sent
        try {
            $bytes_sent = 0;
            $total_bytes = strlen($data);
            while ($bytes_sent < $total_bytes) {
                $sent = socket_write($sock, substr($data, $bytes_sent), $total_bytes - $bytes_sent);
                if ($sent === false) {
                    return false;
                }
                $bytes_sent += $sent;
            }
            return true;
        }
        catch (Exception $e) {}
    }

    private function _send_all($sock, $cmd, $data) {
        # Send data or a command
        try {
            $data_len = strlen($data);
            $header = pack("CN", $cmd, $data_len);
            $msg = $header . $data;
            $success = $this->_sendall($sock, $msg);
            if ($success === false) {
                return false;
            }
            else {
                return true;
            }
        }
        catch (Exception $e){}
    }

    private function _recv_all($sock, $n) {
        # TCP recv n bytes
        # Return val of 0 = no bytes, 1 = error, str = data received
        $data = "";
        $dlen = 0;
        while ($dlen < $n) {
            try {
                $chunk = "";
                $bytes_received = socket_recv($sock, $chunk, ($n - $dlen), 0);
                # Error
                if ($bytes_received === false) {
                    $error_code = socket_last_error($sock);
                    # No Data (non-blocking)
                    if ($error_code == SOCKET_EAGAIN || $error_code == SOCKET_EWOULDBLOCK) {
                        if ((!$data) && ($dlen == 0)) { # Some but not all data yet
                            return 0;
                        }
                    }
                    else {
                        return 1;
                    }
                }
                # Socket closed
                elseif ($bytes_received === 0) {
                    return 1;
                }
                $data .= $chunk;
                $dlen += $bytes_received;
            }
            catch (Exception $e) {
                return 1;
            }
        }
        return $data;
    }

    private function _close($sock) {
        # Close socket
        try {
            socket_close($sock);
        }
        catch (Exception $e) {}
    }

    private function _connect($host, $port) {
        # Connect to the server
        try {
            $s = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
            # Set indefinite timeouts
            socket_set_option($s, SOL_SOCKET, SO_RCVTIMEO, ['sec' => 0, 'usec' => 0]);
            socket_set_option($s, SOL_SOCKET, SO_SNDTIMEO, ['sec' => 0, 'usec' => 0]);
            $result = socket_connect($s, $host, $port);
            # Set non-blocking
            socket_set_nonblock($s);
            if ($result) {
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

}

$revprx = new ReverseProxy("{{CHOST}}", {{CPORT}}, "{{RHOST}}", {{RPORT}});
$revprx->start();
