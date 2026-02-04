#! /usr/bin/perl

use Time::HiRes qw(sleep);
use IO::Socket::INET;

# Initialize Values
$lhost = "{{LHOST}}";
$lport = {{LPORT}};
$rhost = "{{RHOST}}";
$rport = {{RPORT}};
$data_size = 4096;
$verbose = 1;
$client_read = 1;

sub start {
    # Start proxy
    my $s = _bind();
    if ($verbose) {
        print "Listening on $lhost:$lport\n";
    }
    while (1) {
        my $conn = $s->accept();
        if ($verbose) {
            my $ip = $conn->peerhost();
            my $port = $conn->peerport();
            print "Connection received from $ip:$port\n";
        }
        _switch($conn);
    }
}

sub _switch {
    # Switch between read/write
    my $client_sock = $_[0];
    $client_sock->blocking(0); # Non-blocking
    my $server_sock = _connect();
    $server_sock->blocking(0); # Non-blocking
    my $received;
    while (1) {
        # Read from client
        if ($client_read) {
            $received = _recv($client_sock);
            if (!defined($received)) {
                last;
            }
            elsif ($received) {
                _sendall($server_sock, $received);
            }
            else {
                $client_read = 0;
                sleep(0.005);
            }
        }
        # Read from server
        if (!$client_read) {
            $received = _recv($server_sock);
            if (!defined($received)) {
                last;
            }
            elsif ($received) {
                _sendall($client_sock, $received);
            }
            else {
                $client_read = 1;
                sleep(0.005);
            }
        }
    }
    # Close the sockets if not already closed
    _close($client_sock, $server_sock);
}

sub _recv {
    # Receive bytes
    my $recv_sock = $_[0];
    my $data = "";
    my $bytes_read;
    if (defined($bytes_read = $recv_sock->recv($data, $data_size))) {
        if (!$bytes_read and !$data) {
            # Client disconnected gracefully
            return undef;
        }
        return $data;
    }
    return "";
}

sub _sendall {
    my $sock = $_[0];
    my $data_to_send = $_[1];
    my $total_sent = 0;
    my $data_length = length($data_to_send);
    while ($total_sent < $data_length) {
        my $bytes_sent = $sock->send(substr($data_to_send, $total_sent), 0);
        if (!defined $bytes_sent) {
            die "Error sending data: $!";
        }
        $total_sent += $bytes_sent;
    }
}

sub _close {
    # This function is not used in the main flow now but kept for completeness
    my $client = $_[0];
    my $server = $_[1];
    $client->close();
    $server->close();
    if ($verbose) {
        print "Proxied connection closed!\n";
    }
}

sub _connect {
    # Connect to the server
    my $s = new IO::Socket::INET(
        PeerAddr => $rhost,
        PeerPort => $rport,
        Proto    => 'tcp',
        Type     => SOCK_STREAM,
    ) or die "Failed to connect to $rhost:$rport\n";
    if ($verbose) {
        print "Connected to remote host on $rhost:$rport\n";
    }
    return $s;
}

sub _bind {
    my $s = IO::Socket::INET->new(
        LocalAddr => $lhost,
        LocalPort => $lport,
        Proto     => 'tcp',
        Listen    => 25, 
        ReuseAddr => 1, 
    ) or die "Cannot bind listener on $lhost:$lport!\n";
    return $s;
}

start();

