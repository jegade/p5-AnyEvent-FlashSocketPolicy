use warnings;
use strict;
use Test::More tests => 1;
use Test::TCP;
use IO::Socket::INET;
use AnyEvent::FlashSocketPolicy;

SKIP: {
    skip 'skip', 1;
test_tcp(
    client => sub {
        my $port = shift;
        my $sock = IO::Socket::INET->new(
            PeerPort => $port,
            PeerAddr => '127.0.0.1',
            Proto    => 'tcp',
        ) or die "Cannot open client socket: $!";
        my $request = sprintf '<policy-file-request/>%c', 0;
        print {$sock} $request;
        my $response = <$sock>;
        is $response, 'hello';
    },
    server => sub {
        my $port   = shift;
        my $server = AnyEvent::FlashSocketPolicy->new(
            {
                port                            => $port,
                permitted_cross_domain_policies => 'master-only',
                domain                          => 'www.example.com',
                to_ports                        => '3000',
            }
        );
        $server->run;
    }
);
};

