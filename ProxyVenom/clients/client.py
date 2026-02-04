#! /usr/bin/env python3

import time
import struct
import socket

class ProxyClient:

    def __init__(self, chost: str, cport: int, lhost: str, lport: str, verbose: bool=True) -> None:
        '''Initialize reverse TCP proxy'''
        self.chost = chost # Client port
        self.cport = cport
        self.lhost = lhost # local port
        self.lport = lport
        self.data_size = 4096
        self.verbose = verbose

    def start(self) -> None:
        '''Start proxy'''
        s = self._bind(self.chost, self.cport)
        if s:
            s.listen(25)
            if self.verbose:
                print(f"Listening for proxy on {self.chost}:{self.cport}")
            proxy_sock, addr = s.accept()
            proxy_sock.setblocking(0)
            if self.verbose:
                ip, port = addr
                print(f"Proxy connected to client")
            self._listen(proxy_sock)

    def _listen(self, proxy_sock: socket.socket) -> None:
        '''Listen for localhost connections'''
        s = self._bind(self.lhost, self.lport)
        if s:
            s.listen(25)
            if self.verbose:
                print(
                    "Listening for localhost connections on",
                    f"{self.lhost}:{self.lport}"
                )
            while 1:
                try:
                    local_sock, addr = s.accept()
                    local_sock.setblocking(0)
                    if self.verbose:
                        print("Local connection received!")
                    # Tell proxy to connect
                    self._send_all(proxy_sock, 1, b"")
                    self._switch(proxy_sock, local_sock)
                    self._close(local_sock)
                    if self.verbose:
                        print("Local connection closed!")
                except KeyboardInterrupt:
                    self._close(proxy_sock)
                    break

    def _switch(self, proxy_sock: socket.socket, local_sock: socket.socket) -> None:
        '''Switch between read/write'''
        client_read = True
        local_closed = False
        if proxy_sock and local_sock:
            while 1:
                # Recv from client
                if client_read:
                    try:
                        data = local_sock.recv(self.data_size)
                        if data:
                            self._send_all(proxy_sock, 0, data)
                        else:
                            # Local socket is closed
                            if local_closed:
                                self._send_all(proxy_sock, 2, b"")
                                break
                            local_closed = True
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
                        header = self._recv_all(proxy_sock, 5)
                        if header:
                            cmd, data_len = struct.unpack(">BI", header)
                            if cmd == 0:
                                data = self._recv_all(proxy_sock, data_len)
                                if not local_closed:
                                    local_sock.sendall(data)
                                else:
                                    client_read = True
                                    time.sleep(0.005)
                            elif cmd == 2: # close socket
                                break
                        else:
                            client_read = True
                            time.sleep(0.005)
                    except BlockingIOError:
                        client_read = True
                        time.sleep(0.005)
                    except:
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
                dlen += len(chunk)
            except:
                break
        return data

    def _close(self, sock: socket.socket) -> None:
        '''Close socket'''
        try:
            sock.close()
        except:
            pass

    def _bind(self, host: str, port: int) -> socket.socket:
        '''Bind a TCP socket listener'''
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind((host, port))
            return s
        except:
            return None

prxcli = ProxyClient("{{CHOST}}", {{CPORT}}, "{{LHOST}}", {{LPORT}})
prxcli.start()
