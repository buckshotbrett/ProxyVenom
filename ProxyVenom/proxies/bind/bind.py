#! /usr/bin/env python3

import time
import socket

class BindProxy:

    def __init__(self, lhost: str, lport: int, rhost: str, rport: str, verbose: bool=True) -> None:
        '''Initialize TCP proxy'''
        self.lhost = lhost
        self.lport = lport
        self.rhost = rhost
        self.rport = rport
        self.data_size = 4096
        self.verbose = verbose

    def start(self) -> None:
        '''Start proxy'''
        s = self._bind()
        if s:
            s.listen(25)
            if self.verbose:
                print(f"Listening on {self.lhost}:{self.lport}")
            while 1:
                try:
                    conn, addr = s.accept()
                    if self.verbose:
                        ip, port = addr
                        print(f"Connection received from {ip}:{port}")
                    self._switch(conn)
                except KeyboardInterrupt:
                    break

    def _switch(self, client_sock: socket.socket) -> None:
        '''Switch between read/write'''
        server_sock = self._connect()
        if client_sock and server_sock:
            # Make sure recv is not blocking
            client_sock.setblocking(0)
            server_sock.setblocking(0)
            # Switching toggle
            client_read = True
            while 1:
                # Recv from client
                if client_read:
                    try:
                        data = client_sock.recv(self.data_size)
                        if data:
                            server_sock.sendall(data)
                        else:
                            break
                    except BlockingIOError:
                        client_read = False
                        time.sleep(0.005)
                    except:
                        break
                # Recv from server
                if not client_read:
                    try:
                        data = server_sock.recv(self.data_size)
                        if data:
                            client_sock.sendall(data)
                        else:
                            break
                    except BlockingIOError:
                        client_read = True
                        time.sleep(0.005)
                    except:
                        break
        # Close the sockets if any are still open
        self._close(client_sock, server_sock)

    def _close(self, client: socket.socket, server: socket.socket) -> None:
        '''Close client and server sockets'''
        # Close client
        try:
            client.close()
        except:
            pass
        # Close server
        try:
            server.close()
        except:
            pass
        if self.verbose:
            print("Proxied connection closed!")

    def _connect(self) -> socket.socket:
        '''Connect to the server'''
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect((self.rhost, self.rport))
            if self.verbose:
                print(f"Connected to remote host on {self.rhost}:{self.rport}")
            return s
        except:
            return None

    def _bind(self) -> socket.socket:
        '''Bind a TCP socket listener'''
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind((self.lhost, self.lport))
            return s
        except:
            return None

bndprx = BindProxy("{{LHOST}}", {{LPORT}}, "{{RHOST}}", {{RPORT}})
bndprx.start()
