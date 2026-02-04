#! /usr/bin/env ruby

require 'socket'

class BindProxy

  def initialize(lhost, lport, rhost, rport, verbose=true)
    # Initialize TCP proxy
    @lhost = lhost
    @lport = lport
    @rhost = rhost
    @rport = rport
    @data_size = 4096
    @verbose = verbose
  end

  def start
    s = _bind
    if s
      s.listen(25)
      if @verbose
        puts "Listening on #{@lhost}:#{@lport}"
      end
      while true
        begin
          conn, addr = s.accept
          if @verbose
            ip = addr.ip_address
            port = addr.ip_port
            puts "Connection received from #{ip}:#{port}"
          end
          _switch(conn)
        rescue Interrupt
          break
        rescue => e
          puts "ERROR: #{e.message}"
          break
        end
      end
    end
  end

  def _switch(client_sock)
    server_sock = _connect
    if client_sock && server_sock
      client_read = true
      while true
        # Recv from client
        if client_read
          begin
            data = client_sock.recv_nonblock(@data_size)
            if data
              _sendall(server_sock, data)
            else
              break
            end
          rescue IO::WaitReadable
            client_read = false
            sleep 0.005
          rescue
            break
          end
        end
        # Recv from server
        if !client_read
          begin
            data = server_sock.recv_nonblock(@data_size)
            if data
              _sendall(client_sock, data)
            else
              break
            end
          rescue IO::WaitReadable
            client_read = true
            sleep 0.005
          rescue
            break
          end
        end
      end
      # Close the sockets if any are still open
      _close(client_sock, server_sock)
    end
  end

  def _sendall(sock, data)
    bytes_sent = 0
    while bytes_sent < data.length
      sent_count = sock.write(data.byteslice(bytes_sent..-1))
      bytes_sent += sent_count
    end
  end

  def _close(client, server)
    # Close client and server sockets
    begin
      client.close
    rescue
      nil
    end
    begin
      server.close
    rescue
      nil
    end
    if @verbose
      puts "Proxied connection closed!"
    end
  end

  def _connect
    # Connect to the server
    begin
      s = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      addr = Socket.pack_sockaddr_in(@rport, @rhost)
      s.connect(addr)
      if @verbose
        puts "Connected to remote host on #{@rhost}:#{@rport}"
      end
      return s
    rescue
      return nil
    end
  end

  def _bind
    begin
      s = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      s.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
      addr = Addrinfo.tcp(@lhost, @lport)
      s.bind(addr)
      return s
    rescue
      return nil
    end
  end
end

bndprx = BindProxy.new("{{LHOST}}", {{LPORT}}, "{{RHOST}}", {{RPORT}})
bndprx.start
