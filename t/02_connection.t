use warnings;
use strict;
use Test::More tests => 1;
use Perl6::Slurp;
use Test::TCP;
use IO::Socket::INET;
use AnyEvent::FlashSocketPolicy;

my $expected_response1 = <<'__TEST1_RESPONSE__';
<?xml version="1.0"?>
<!DOCTYPE cross-domain-policy SYSTEM "http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd">
<cross-domain-policy>
    <site-control permitted-cross-domain-policies="master-only"/>
    <allow-access-from domain="www.example.com" to-ports="3000"/>
</cross-domain-policy>
__TEST1_RESPONSE__
$expected_response1 .= "\0\n";

test_tcp(
    client => sub {
        my $port = shift;
        my $sock = IO::Socket::INET->new(
            PeerPort => $port,
            PeerAddr => '127.0.0.1',
            Proto    => 'tcp',
        ) or die "Cannot open client socket: $!";
        my $request = "<policy-file-request/>\0";
        print {$sock} $request;
        my $response = slurp $sock;
        is $response, $expected_response1;
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

