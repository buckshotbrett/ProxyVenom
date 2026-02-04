#! /usr/bin/env ruby

require 'socket'

class ReverseProxy

  def initialize(chost, cport, rhost, rport, verbose=true)
    # Initialize TCP proxy
    @chost = chost
    @cport = cport
    @rhost = rhost
    @rport = rport
    @data_size = 4096
    @verbose = verbose
  end

  def start
    # Start proxy
    client_sock = _connect(@chost, @cport)
    if client_sock
      if @verbose
        puts "Proxy connected to client."
      end
      while true
        begin
          header = _recv_all(client_sock, 5)
          if !(header.nil? || header.empty?)
            cmd, data_len = header.unpack("CI>")
            # connect to remote host
            if cmd == 1
              server_sock = _connect(@rhost, @rport)
              if @verbose
                puts "Proxy connected to remote host."
              end
              _switch(client_sock, server_sock)
              _close(server_sock)
              if @verbose
                puts "Proxy disconnected from remote host."
              end
            end
          else
            sleep 0.005
          end
        rescue Interrupt
          break
        rescue => e
          puts "ERROR: #{e.message}"
          break
        end
      end
    end
  end

  def _switch(client_sock, server_sock)
    server_closed = false
    if client_sock && server_sock
      client_read = true
      while true
        # Recv from client
        if client_read
          begin
            header = _recv_all(client_sock, 5)
            if !(header.nil? || header.empty?)
              cmd, data_len = header.unpack("CI>")
              if cmd == 0
                data = _recv_all(client_sock, data_len)
                if !server_closed
                  _sendall(server_sock, data)
                else
                  client_read = false
                  sleep 0.005
                end
              elsif cmd == 2
                break
              end
            else
              client_read = false
              sleep 0.005
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
            if !(data.nil? || data.empty?)
              _send_all(client_sock, 0, data)              
            else
              if server_closed
                _send_all(client_sock, 2, "")
                break
              end
              server_closed = true
              client_read = true
              sleep 0.005
            end
          rescue IO::WaitReadable
            client_read = true
            sleep 0.005
          rescue
            _send_all(client_sock, 2, "")
            break
          end
        end
      end
    end
  end

  def _send_all(sock, cmd, data)
    # Send data or a command
    begin
      data_len = data.length
      header = [cmd, data_len].pack("CI>")
      msg = header + data
      _sendall(sock, msg)
    rescue
      nil
    end
  end

  def _sendall(sock, data)
    # Block until all bytes are sent
    bytes_sent = 0
    while bytes_sent < data.length
      sent_count = sock.write(data.byteslice(bytes_sent..-1))
      bytes_sent += sent_count
    end
  end

  def _recv_all(sock, n)
    # TCP recv n bytes
    data = ""
    dlen = 0
    while dlen < n
      begin
        chunk = sock.recv_nonblock(n - dlen)
        if (chunk.nil? || chunk.empty?) && dlen == 0
          break
        end
        data += chunk
        dlen += chunk.length
      rescue
        break
      end
    end
    return data
  end

  def _close(sock)
    # Close socket
    begin
      sock.close
    rescue
      nil
    end
  end

  def _connect(host, port)
    # Connect to a remote port
    begin
      s = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      addr = Socket.pack_sockaddr_in(port, host)
      s.connect(addr)
      return s
    rescue
      return nil
    end
  end

end

revprx = ReverseProxy.new("{{CHOST}}", {{CPORT}}, "{{RHOST}}", {{RPORT}})
revprx.start
