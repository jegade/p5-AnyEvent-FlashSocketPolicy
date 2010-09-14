use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

use AnyEvent::FlashSocketPolicy;

# test1
my $server = AnyEvent::FlashSocketPolicy->new(
    {
        permitted_cross_domain_policies => 'all',
        domain                          => 'www.example.com',
        to_ports                        => '3000',
    }
);
my $result = <<'__RESULT__';
<?xml version="1.0"?>
<!DOCTYPE cross-domain-policy SYSTEM "http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd">
<cross-domain-policy>
    <site-control permitted-cross-domain-policies="all"/>
    <allow-access-from domain="www.example.com" to-ports="3000"/>
</cross-domain-policy>
__RESULT__
$result .= pack( 'c', 0 ) . "\n";
is $result, $server->policy, 'normal creation test';

# test2
$server->domain('*');
$result = <<'__RESULT__';
<?xml version="1.0"?>
<!DOCTYPE cross-domain-policy SYSTEM "http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd">
<cross-domain-policy>
    <site-control permitted-cross-domain-policies="all"/>
    <allow-access-from domain="*" to-ports="3000"/>
</cross-domain-policy>
__RESULT__
$result .= pack( 'c', 0 ) . "\n";
is $result, $server->policy, 'change attribute test';

# test3
throws_ok {
    AnyEvent::FlashSocketPolicy->new(
        {
            permitted_cross_domain_policies => 'hoge',
            domain                          => 'www.example.com',
            to_ports                        => '3000',
        }
    );
}
qr{^Attribute}, 'invalid permitted_cross_domain_policies';

