class BindProxy {
    [string]$lhost
    [int]$lport
    [string]$rhost
    [int]$rport
    [string]$LastName
    [int]$data_size
    [bool]$verbose

    # Constructor
    BindProxy([string]$lhost, [int]$lport, [string]$rhost, [int]$rport, [bool]$verbose=$true) {
        # Initialize TCP proxy
        $this.lhost = $lhost
        $this.lport = $lport
        $this.rhost = $rhost
        $this.rport = $rport
        $this.verbose = $verbose
        $this.data_size = 4096
    }

    [void]start() {
        # Start proxy
        $s = $this._bind()
        if ($s) {
            $s.Start(25) # Listen
            if ($this.verbose) {
                Write-Host "Listening on $($this.lhost):$($this.lport)"
            }
            try {
                while ($true) {
                    if ($s.Pending()) {
                        $conn = $s.AcceptTcpClient()
                    }
                    else {
                        Start-Sleep -Milliseconds 100
                        continue
                    }
                    if ($this.verbose) {
                        $hst = $conn.Client.RemoteEndPoint
                        $ip = $hst.Address.ToString()
                        $port = $hst.Port
                        Write-Host "Connection received from $($ip):$($port)"
                    }
                    $this._switch($conn)
                }
            }
            catch [System.Management.Automation.RuntimeException] {
                break
            }
            finally {
                $s.Stop()
            }
        }
    }

    [void]_switch([System.Net.Sockets.TcpClient]$client) {
        # Switch between read/write
        $server = $this._connect()
        if ($client -and $server) {
            # Set sockets to non-blocking
            $client.Client.Blocking = $false
            $client_sock = $client.Client
            $server.Client.Blocking = $false
            $server_sock = $server.Client
            # Switching toggle
            $client_read = $true
            $data = New-Object byte[] $this.data_size
            while ($true) {
                # Recv from client
                if ($client_read) {
                    if ($client_sock.Poll(100, [System.Net.Sockets.SelectMode]::SelectRead)) {
                        $bytes_read = 0
                        try {
                            $bytes_read = $client_sock.Receive($data)
                            if ($bytes_read -gt 0) {
                                $received_data = $data[0..($bytes_read - 1)]
                                $this._sendall($server_sock, $received_data)
                            }
                            elseif ($bytes_read -eq 0) {
                                # Peer closed gracefully
                                break
                            }
                        }
                        catch [System.Net.Sockets.SocketException] {
                            if ($_.Exception.NativeErrorCode -eq 10035) {
                                # Socket open but no data available
                                $client_read = $false
                                Start-Sleep -Milliseconds 5
                            }
                            else {
                                # Other error
                                break
                            }
                        }
                        catch {
                            # Any other exception
                            break
                        }
                    }
                    else {
                        $client_read = $false
                        Start-Sleep -Milliseconds 5
                    }
                }
                # Recv from server
                if (-not $client_read) {
                    if ($server_sock.Poll(100, [System.Net.Sockets.SelectMode]::SelectRead)) {
                        $bytes_read = 0
                        try {
                            $bytes_read = $server_sock.Receive($data)
                            if ($bytes_read -gt 0) {
                                $received_data = $data[0..($bytes_read - 1)]
                                $this._sendall($client_sock, $received_data)
                            }
                            elseif ($bytes_read -eq 0) {
                                # Peer closed gracefully
                                break
                            }
                        }
                        catch [System.Net.Sockets.SocketException] {
                            if ($_.Exception.NativeErrorCode -eq 10035) {
                                # Socket open but no data available
                                $client_read = $true
                                Start-Sleep -Milliseconds 5
                            }
                            else {
                                # Other error
                                break
                            }
                        }
                        catch {
                            # Any other exception
                            break
                        }
                    }
                    else {
                        $client_read = $true
                        Start-Sleep -Milliseconds 5
                    }
                }
            }
            # Close the sockets if any are still open
            $this._close($client, $server)
        }
    }

    [void]_sendall([System.Net.Sockets.Socket]$sock, [byte[]]$data) {
        $bytes_sent = 0
        $total_bytes = $data.Length
        $sock.NoDelay = $true
        while ($bytes_sent -lt $total_bytes) {
            $remaining_bytes = $total_bytes - $bytes_sent
            $sent = $sock.Send($data, $bytes_sent, $remaining_bytes, [System.Net.Sockets.SocketFlags]::None)
            $bytes_sent += $sent
        }
    }

    [void]_close([System.Net.Sockets.TcpClient]$client, [System.Net.Sockets.TcpClient]$server) {
        # Close client and server sockets
        # Close client
        Try {
            $client.close()
        }
        Catch {}
        # Close server
        Try {
            $server.close();
        }
        Catch {}
        if ($this.verbose) {
            Write-Host "Proxied connection closed!"
        }
    }

    [System.Net.Sockets.TcpClient]_connect() {
        # Connect to the server
        Try {
            $s = New-Object System.Net.Sockets.TcpClient($this.rhost, $this.rport)
            if ($this.verbose) {
                Write-Host "Connected to remote host on $($this.rhost):$($this.rport)"
            }
            return $s
        }
        Catch {
            return $null
        }
    }

    [System.Net.Sockets.TcpListener]_bind() {
        # Bind a TCP Socket Listener
        Try {
            $s = New-Object System.Net.Sockets.TcpListener($this.lhost, $this.lport)
            $s.Server.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, 1)
            return $s
        }
        Catch {
            return $null
        }
    }
}

$bndprx = [BindProxy]::new("{{LHOST}}", {{LPORT}}, "{{RHOST}}", {{RPORT}}, $True)
$bndprx.start()
