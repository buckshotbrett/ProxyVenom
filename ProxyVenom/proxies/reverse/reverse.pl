#! /usr/bin/perl

use Time::HiRes qw(sleep);
use IO::Socket::INET;

# Initialize Values
$chost = "{{CHOST}}";
$cport = {{CPORT}};
$rhost = "{{RHOST}}";
$rport = {{RPORT}};
$data_size = 4096;
$verbose = 1;

sub start {
    # Start proxy
    my $client_sock = _connect($chost, $cport);
    if ($client_sock) {
        if ($verbose) {
            print "Proxy connected to client.\n";
        }
        while (1) {
            my $header = _recv_all($client_sock, 5);
            if ($header) {
                my ($cmd, $data_len) = unpack("CI>", $header);
                # connect to remote host
                if ($cmd == 1) {
                    my $server_sock = _connect($rhost, $rport);
                    if ($verbose) {
                        print "Proxy connected to remote host.\n";
                    }
                    _switch($client_sock, $server_sock);
                    _close($server_sock);
                    if ($verbose) {
                        print "Proxy disconnected from remote host.\n";
                    }
                }
            }
            else {
                sleep(0.005);
            }
        }
        _close($client_sock);
    }
}

sub _switch {
    # Switch between read/write
    my $client_sock = $_[0];
    my $server_sock = $_[1];
    my $data = "";
    my $client_read = 1;
    my $server_closed = 0;
    if ($client_sock and $server_sock) {
        while (1) {
            # Recv from client
            if ($client_read) {
                my $header = _recv_all($client_sock, 5);
                if (!defined($header)) {
                    last;
                }
                elsif ($header) {
                    my ($cmd, $data_len) = unpack("CI>", $header);
                    if ($cmd == 0) {
                        $data = _recv_all($client_sock, $data_len);
                        if (!$server_closed) {
                            _sendall($server_sock, $data);
                        }
                        else {
                            $client_read = 0;
                            sleep(0.005);
                        }
                    }
                    elsif ($cmd == 2) { # close socket
                        last;
                    }
                }
                else {
                    $client_read = 0;
                    sleep(0.005);
                }
            }
            # Recv from server
            if (!$client_read) {
                $data = _recv($server_sock);
                if (!defined($data)) {
                    if ($server_closed) {
                        _send_all($client_sock, 2, "");
                        last;
                    }
                    $server_closed = 1;
                    $client_read = 1;
                    sleep(0.005);
                }
                elsif ($data) {
                    _send_all($client_sock, 0, $data);
                }
                else {
                    $client_read = 1;
                    sleep(0.005);
                }
            }
        }
    }
}

sub _send_all {
    # Send data or a command
    my $sock = $_[0];
    my $cmd = $_[1];
    my $data = $_[2];
    my $data_len = length($data);
    my $header = pack("CI>", $cmd, $data_len);
    my $msg = $header . $data;
    _sendall($sock, $msg);
}

sub _sendall {
    # Send until all data is sent
    my $soc = $_[0];
    my $data_to_send = $_[1];
    my $total_sent = 0;
    my $data_length = length($data_to_send);
    while ($total_sent < $data_length) {
        my $bytes_sent = $soc->send(substr($data_to_send, $total_sent), 0);
        if (!defined $bytes_sent) {
            die "Error sending data: $!";
        }
        $total_sent += $bytes_sent;
    }
}

sub _recv_all {
    # TCP recv n bytes
    my $so = $_[0];
    my $n = $_[1];
    my $data = "";
    my $chunk = "";
    my $dlen = 0;
    my $bytes_read = "";
    while ($dlen < $n) {
        if (defined($bytes_read = $so->recv($chunk, ($n - $dlen)))) {
            if (!$bytes_read and !$chunk) {
                # Socket is closed
                return undef;
            }
            $data .= $chunk;
            $dlen += length($chunk);
        }
        else {
            # No data available
            return "";
        }
    }
    # Return available data of specified length
    return $data;
}

sub _recv {
    # Receive bytes
    my $recv_sock = $_[0];
    my $data = "";
    my $bytes_read = "";
    if (defined($bytes_read = $recv_sock->recv($data, $data_size))) {
        if (!$bytes_read and !$data) {
            # Client disconnected gracefully
            return undef;
        }
        return $data;
    }
    return "";
}

sub _close {
    # Close socket
    my $sck = $_[0];
    $sck->close();
}

sub _connect {
    # Connect to a remote port
    my $host = $_[0];
    my $port = $_[1];
    my $s = new IO::Socket::INET(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Type     => SOCK_STREAM,
    ) or return undef;
    $s->blocking(0); # Non-blocking
    return $s;
}

start();

