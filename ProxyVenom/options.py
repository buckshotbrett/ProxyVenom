#! /usr/bin/env python3

import os
import base64
import argparse

class Options:

    def __init__(self) -> None:
        '''Initialize option parser'''
        # Define proxy types
        self.proxy_types = [
            ["pl", "Perl"],
            ["py", "Python"],
            ["rb", "Ruby"],
            ["php", "PHP"],
            ["ps1", "PowerShell"],
            ["js", "Nodejs"]
        ]
        # Define stager paths
        self.stagers = os.path.join(os.path.dirname(__file__), "stagers")
        self.http_stagers = os.path.join(self.stagers, "http")
        self.tcp_stagers = os.path.join(self.stagers, "tcp")
        self.prompt_stagers = os.path.join(self.stagers, "prompt")
        # Build argument parser
        parser = argparse.ArgumentParser(
            description="A TCP proxy payload generator for offensive security."
        )
        subparsers = parser.add_subparsers(
            dest="type",
            metavar="TYPE",
            required=True,
            help="Choose a proxy type."
        )
        self._add_bind_args(subparsers)
        self._add_reverse_args(subparsers)
        self.args = parser.parse_args()

    def _add_bind_args(self, subparsers) -> None:
        '''Parse arguments for a TCP Bind proxy'''
        bind = subparsers.add_parser(
            "bind",
            help="Create a TCP proxy on the target host "
            "by binding a listener.",
            formatter_class=argparse.RawTextHelpFormatter
        )
        bind.add_argument(
            "--lhost",
            type=str,
            required=False,
            default="0.0.0.0",
            help="The host interface to bind a proxy port.\n(Default: 0.0.0.0)"
        )
        bind.add_argument(
            "--lport",
            type=str,
            required=True,
            help="The port to listen on for proxy connections.\n "
        )
        bind.add_argument(
            "--rhost",
            type=str,
            required=True,
            help="The target IP of the proxied traffic."
        )
        bind.add_argument(
            "--rport",
            type=str,
            required=True,
            help="The target port of the proxied traffic.\n "
        )
        # Add subparsers for each code family
        proxies = bind.add_subparsers(
            dest="lang",
            metavar="LANGUAGE",
            required=True,
            help="Proxy and stager scripting language."
        )
        self._add_proxy_types(proxies)

    def _add_proxy_types(self, proxies) -> None:
        '''Add parsers for each proxy scripting language'''
        for ext, name in self.proxy_types:
            lang=proxies.add_parser(
                f"{ext}",
                help=f"{name} proxy and stagers."
            )
            # Add subparsers for delivery methods
            delivery = lang.add_subparsers(
                dest="delivery",
                metavar="DELIVERY",
                required=True,
                help="Delivery method."
            )
            self._add_file_delivery_args(delivery, name)
            self._add_http_delivery_args(delivery, name, ext)
            self._add_tcp_delivery_args(delivery, name, ext)
            self._add_prompt_delivery_args(delivery, name, ext)

    def _add_file_delivery_args(self, delivery, name) -> None:
        '''Add arguments for file delivery'''
        file = delivery.add_parser(
            "file",
            help=f"Deliver the {name} proxy manually as a file.",
            formatter_class=argparse.RawTextHelpFormatter
        )
        file.add_argument(
            "--outfile",
            type=str,
            required=True,
            help="The path to the output file."
        )

    def _add_http_delivery_args(self, delivery, name, ext) -> None:
        '''Add arguments for HTTP delivery'''
        http = delivery.add_parser(
            "http",
            help=f"Deliver the {name} proxy by executing a "
            f"{name} one-liner HTTP stager."
        )
        http.add_argument(
            "--server-ip",
            type=str,
            required=True,
            help="The IP of the HTTP server."
        )
        http.add_argument(
            "--server-port",
            type=str,
            required=True,
            help="The port of the HTTP server."
        )
        h = os.listdir(self.http_stagers)
        http.add_argument(
            "--stager",
            type=str,
            required=True,
            choices=[i.replace(f".{ext}","") for i in h if i.endswith(ext)],
            help="Choose an HTTP stager."
        )
        http.add_argument(
            "--outfile",
            type=str,
            required=True,
            help="The path to the output file to serve via HTTP."
        )

    def _add_tcp_delivery_args(self, delivery, name, ext) -> None:
        '''Add arguments for tcp payload delivery'''
        tcp = delivery.add_parser(
            "tcp",
            help=f"Deliver the {name} proxy by executing a "
            f"{name} one-liner TCP stager."
        )
        tcp.add_argument(
            "--server-ip",
            type=str,
            required=True,
            help="The IP of the TCP server."
        )
        tcp.add_argument(
            "--server-port",
            type=str,
            required=True,
            help="The port of the TCP server."
        )
        t = os.listdir(self.tcp_stagers)
        tcp.add_argument(
            "--stager",
            type=str,
            required=True,
            choices=[i.replace(f".{ext}","") for i in t if i.endswith(ext)],
            help="Choose a TCP stager."
        )
        tcp.add_argument(
            "--outfile",
            type=str,
            required=True,
            help="The path to the output file to serve via TCP."
        )

    def _add_prompt_delivery_args(self, delivery, name, ext) -> None:
        '''Add arguments for stdin user prompt payload delivery'''
        prmpt = delivery.add_parser(
            "prompt",
            help=f"Deliver the {name} proxy by executing a {name} one-liner "
            "that prompts the user for the full payload."
        )
        p = os.listdir(self.prompt_stagers)
        prmpt.add_argument(
            "--stager",
            type=str,
            required=True,
            choices=[i.replace(f".{ext}","") for i in p if i.endswith(ext)],
            help="Choose a prompt stager."
        )

    def _add_reverse_args(self, subparsers) -> None:
        '''Add arguments for reverse TCP proxy'''
        reverse = subparsers.add_parser(
            "reverse",
            help="Create a TCP proxy on the target host by creating a reverse "
            "TCP connection to a client on the attacker machine.",
            formatter_class=argparse.RawTextHelpFormatter
        )
        reverse.add_argument(
            "--lhost",
            type=str,
            required=False,
            default="127.0.0.1",
            help="Client interface for forwarding traffic\n"
            "TCP traffic forwarded through the proxy via this interface\n"
            "(Default: 127.0.0.1)"
        )
        reverse.add_argument(
            "--lport",
            type=str,
            required=False,
            default="3128",
            help="Client port for forwarding traffic\n"
            "TCP traffic forwarded through the proxy via this port\n"
            "(Default: 3128)"
        )
        reverse.add_argument(
            "--chost",
            type=str,
            required=True,
            help="Reverse TCP proxy listener interface\n"
            "The proxy connects to client on this interface"
        )
        reverse.add_argument(
            "--cport",
            type=str,
            required=False,
            default="4321",
            help="Reverse TCP proxy listener port\n"
            "The proxy connects to the client on this port\n"
            "(Default: 4321)"
        )
        reverse.add_argument(
            "--rhost",
            type=str,
            required=True,
            help="The target IP of the proxied traffic."
        )
        reverse.add_argument(
            "--rport",
            type=str,
            required=True,
            help="The target port of the proxied traffic."
        )
        # Add subparsers for each code family
        proxies = reverse.add_subparsers(
            dest="lang",
            metavar="LANGUAGE",
            required=True,
            help="Proxy and stager scripting language."
        )
        self._add_proxy_types(proxies)

