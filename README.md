# ProxyVenom
ProxyVenom is inspired by msfvenom, but rather than generate shell payloads, it generates TCP proxies that leverage common living-off-the-land scripting languages. It currently supports Perl, Python, Ruby, PHP, PowerShell, and NodeJS. The proxies are lightweight, single-threaded applications and can be executed in a simple shell. When you build your proxy, you choose a method for staging it's delivery, including file, TCP, HTTP, and command line prompt input.

For those interested, the way I chose to implement this is by using fast switching between non-blocking TCP sockets. If data can't be read from one socket (e.g. the client) immediately, it switches to the other socket (e.g. the server) to try to read from there and continues switching until data becomes available. Whichever direction data is flowing, it will relay it in a loop until there is no more data available, and then it resumes switching.

## Basic Usage
ProxyVenom has various levels of options that allow you to configure the type, language, and delivery method ("stager") of your TCP proxy. Begin by running the following:

`python3 ProxyVenom/proxyvenom.py -h`

You will see output as follows:

<img width="1264" height="352" alt="type" src="https://github.com/user-attachments/assets/587e3913-4579-485b-9561-cb046bce0fd3" />

You must start by specifying the type of proxy you want to generate. Then use the `-h` flag to reveal more options. For this example, we will generate a `bind` tcp proxy, which will bind an open port for the proxy on the interface you specify on the victim machine.

`python3 ProxyVenom/proxyvenom.py bind -h`

This will show the following options:

<img width="1021" height="536" alt="network" src="https://github.com/user-attachments/assets/c253fd65-5d3f-48bd-8e05-e8362a80a37e" />

As you can see, you must specify your network configuration and choose the scripting language of the TCP proxy payload (and stagers). For this example I will use perl. I will keep the default `--lhost` option (0.0.0.0) to bind on and I will forward traffic from TCP port 3128 to localhost port 3306 to access MySQL. 

`python3 ProxyVenom/proxyvenom.py bind --lport 3128 --rhost 127.0.0.1 --rport 3306 pl -h`

The options then prompt you to specify a staging method.

<img width="1110" height="351" alt="stager" src="https://github.com/user-attachments/assets/3edc6f4e-c10c-4352-8322-5864ae2aeedb" />

For this example, I will choose the `file` method.

`python3 ProxyVenom/proxyvenom.py bind --lport 3128 --rhost 127.0.0.1 --rport 3306 pl file -h`

Viewing my options one more time, I see an `--outfile` flag for the payload.

<img width="587" height="223" alt="outfile" src="https://github.com/user-attachments/assets/44b43061-0267-474c-8057-d7c257f7c30f" />

By specifying the output file, the tool generates the TCP proxy payload.

`python3 ProxyVenom/proxyvenom.py bind --lport 3128 --rhost 127.0.0.1 --rport 3306 pl file --outfile prx.pl`

<img width="536" height="203" alt="payload" src="https://github.com/user-attachments/assets/4216b85c-019d-4fee-837a-c0da12e2ec7a" />

This file can then be uploaded to the victim machine and executed with the perl interpreter to launch the TCP proxy. The attacker can now access the MySQL service on TCP port 3128.

## Reverse TCP Payloads
The reverse TCP proxy type connects back from the victim machine to the attacker machine. However, traffic is still forwarded through the victim machine just as the bind proxy does. This requires the use of a client, which will also be generated along with the payload, through which all attacker traffic must be forwarded. The reverse TCP proxy is ideal if you are working on a CTF challenge with other competitors. A bind proxy will open up your port to the world, but a reverse TCP proxy only allows you to forward traffic through your proxy.

Instead of specifying `bind`, specify `reverse` and look at your options:

`python3 ProxyVenom/proxyvenom.py reverse -h`

You can see some additional options, namely `--chost` and `--cport`. The `--chost` option specifies the IP your client will listen on for the reverse TCP connection from the proxy. `--cport` specifies the TCP port the client will listen on for that reverse connection, which defaults to TCP port 4321. The `--lhost` option is used by the client to bind a local listener, and the default is 127.0.0.1. `--lport` specifies the client's local port through which all traffic will flow, which defaults to 3128. The `--rhost` and `--rport` options remain the remote IP and port of the remote service that is the proxy's destination.

<img width="1190" height="571" alt="chost" src="https://github.com/user-attachments/assets/b35815e0-2934-4185-8c1f-726fc79d9017" />

For this example, I will still target a localhost MySQL service on the victim machine. I will specify the IP and port of the client's proxy listener to be 10.10.14.12:4321. Finally, I will leave my localhost listener as the default TCP port 3128. I will once again use Perl as the proxy scripting language.

`python3 ProxyVenom/proxyvenom.py reverse --chost 10.10.14.12 --rhost 127.0.0.1 --rport 3306 pl -h`

Once again, you are presented with a choice for delivery.

<img width="1105" height="242" alt="delivery" src="https://github.com/user-attachments/assets/e65113b8-2fec-4135-8cde-17ab65677b1a" />

Specify the `--outfile`` flag once more to generate the payload.

`python3 ProxyVenom/proxyvenom.py reverse --chost 10.10.14.12 --rhost 127.0.0.1 --rport 3306 pl file --outfile prx.pl`

As you can see, this time you not only generate a proxy file, but also the client file. The client should be executed on the attacker machine before the proxy is executed on the victim machine.

<img width="611" height="322" alt="payload" src="https://github.com/user-attachments/assets/1dcc79c6-9298-4a7b-96b7-6a7862e8cdc8" />

Once the proxy is executed on the victim machine and has successfully connected to the attacker's client, the attacker can now access the remote database service through a localhost listener. For example:

`mysql -A -h 127.0.0.1 -P 3128 -u wordpress -p`

## Using Stagers
Stagers allow you to deliver the payload using a simple command shell in simple ways. The above examples have focused on file delivery. However, ProxyVenom also supports HTTP, TCP, and command prompt delivery. These stagers generate a one-liner command that can be executed in your shell execute the proxy in memory. Stagers are named by the language-specific method used to implement the core functionality of the stager. For example, a python HTTP stager can use either the python requests library or the urllib library. The requests library may not be installed, but urllib is always present. You have the option to specify which one to use, but most stagers only have one option. Example:

`python3 ProxyVenom/proxyvenom.py bind --lport 3128 --rhost 127.0.0.1 --rport 3306 py http -h`

<img width="1236" height="374" alt="http" src="https://github.com/user-attachments/assets/6240fd04-5af0-40d4-acea-99eaf0288afc" />

Both the HTTP and TCP stagers require you to specify `--server-ip` and `--server-port` options. For the python basic HTTP server, the default port is 8000. I will specify the attacker machine as the server IP.

`python3 ProxyVenom/proxyvenom.py bind --lport 3128 --rhost 127.0.0.1 --rport 3306 py http --server-ip 10.10.14.12 --server-port 8000 --stager urllib --outfile prx.py`

As you can see, this generates a one-liner to execute in your shell on the victim machine in addition to the bind TCP proxy file. Start your web server, execute the one-liner, and the proxy will execute in memory on the victim machine. Using a TCP stager works very much the same way, but the file can be served with netcat and I/O redirection.

Finally, generating a prompt stager is done as follows:

`python3 ProxyVenom/proxyvenom.py bind --lport 3128 --rhost 127.0.0.1 --rport 3306 py prompt --stager input`

In this example, a bind python TCP proxy would be delivered via the python `input()` function. The payload is compressed and encoded. Executing the one-liner on the victim machine will prompt you for that encoded payload string. Enter that in and the payload will execute in memory on the victim machine.

<img width="1322" height="534" alt="prompt" src="https://github.com/user-attachments/assets/7f6b092d-5492-4806-bd0e-4aee5074cfee" />


