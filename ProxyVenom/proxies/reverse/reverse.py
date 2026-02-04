#! /usr/bin/env python3

import time
import struct
import socket

class ReverseProxy:

    def __init__(self, chost: str, cport: int, rhost: str, rport: str, verbose: bool=True) -> None:
        '''Initialize reverse TCP proxy'''
        self.chost = chost # Client host
        self.cport = cport
        self.rhost = rhost # Remote host
        self.rport = rport
        self.data_size = 4096
        self.verbose = verbose

    def start(self) -> None:
        '''Start proxy'''
        client_sock = self._connect(self.chost, self.cport)
        if client_sock:
            if self.verbose:
                print("Proxy connected to client.")
            while 1:
                try:
                    header = self._recv_all(client_sock, 5)
                    if header:
                        cmd, data_len = struct.unpack(">BI", header)
                        # connect to remote host
                        if cmd == 1:
                            server_sock = self._connect(self.rhost, self.rport)
                            if self.verbose:
                                print("Proxy connected to remote host.")
                            self._switch(client_sock, server_sock)
                            self._close(server_sock)
                            if self.verbose:
                                print("Proxy disconnected from remote host.")
                    else:
                        time.sleep(0.005)
                except KeyboardInterrupt:
                    break
            self._close(client_sock)

    def _switch(self, client_sock: socket.socket, server_sock: socket.socket) -> None:
        '''Switch between read/write'''
        server_closed = False
        if client_sock and server_sock:
            # Switching toggle
            client_read = True
            while 1:
                # Recv from client
                if client_read:
                    try:
                        header = self._recv_all(client_sock, 5)
                        if header:
                            cmd, data_len = struct.unpack(">BI", header)
                            if cmd == 0:
                                data = self._recv_all(client_sock, data_len)
                                if not server_closed:
                                    server_sock.sendall(data)
                                else:
                                    client_read = False
                                    time.sleep(0.005)
                            elif cmd == 2: # close socket
                                break
                        else:
                            client_read = False
                            time.sleep(0.005)
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
                            self._send_all(client_sock, 0, data)
                        else:
                            # Server socket is closed
                            if server_closed:
                                self._send_all(client_sock, 2, b"")
                                break
                            server_closed = True
                            client_read = True
                            time.sleep(0.005)
                    except BlockingIOError:
                        client_read = True
                        time.sleep(0.005)
                    except:
                        self._send_all(client_sock, 2, b"")
                        break

    def _send_all(self, sock: socket.socket, cmd: int, data: bytes) -> None:
        '''Send data or a command'''
        try:
            data_len = len(data)
            header = struct.pack(">BI", cmd, data_len)
            msg = header + data
            sock.sendall(msg)
        except:
            pass

    def _recv_all(self, sock: socket.socket, n: int) -> bytes:
        '''TCP recv n bytes'''
        data = b""
        dlen = 0
        while dlen < n:
            try:
                chunk = sock.recv(n - dlen)
                if (not chunk) and (dlen == 0): # no data
                    break
                data += chunk
                dlen += chunk.length
            except:
                break
        return data

    def _close(self, sock: socket.socket) -> None:
        '''Close socket'''
        try:
            sock.close()
        except:
            pass

    def _connect(self, host: str, port: int) -> socket.socket:
        '''Connect to a remote port'''
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect((host, port))
            s.setblocking(0)
            return s
        except:
            return None

revprx = ReverseProxy("{{CHOST}}", {{CPORT}}, "{{RHOST}}", {{RPORT}})
revprx.start()
