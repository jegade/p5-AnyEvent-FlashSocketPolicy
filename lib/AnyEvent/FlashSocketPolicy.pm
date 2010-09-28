package AnyEvent::FlashSocketPolicy;
use Any::Moose;
use Any::Moose '::Util::TypeConstraints';
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Socket qw(IPPROTO_TCP TCP_NODELAY);
use Text::MicroTemplate qw(render_mt);
use Carp;
use Try::Tiny;

# TODO: IPアドレス制限
# TODO: ベンチマーク
# TODO: 指定されたポリシーファイルの読み込み
# TODO: ポリシーファイルの変更監視
# TODO: 例外処理
# TODO: ログの生成(不正なリクエストヘッダ。アクセス元IPアドレス)

use 5.008008;
our $VERSION = '0.02';

use constant POLICY_REQUEST => "<policy-file-request/>\0";
use constant DEBUG          => $ENV{FLASH_SOCKET_POLICY_DEBUG} || 0;
use constant LISTEN_PORT    => 843;
use constant TEMPLATE       => <<'__TEMPLATE__';
?= Text::MicroTemplate::encoded_string '<?xml version="1.0"?>'
<!DOCTYPE cross-domain-policy SYSTEM "http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd">
<cross-domain-policy>
    <site-control permitted-cross-domain-policies="<?= $_[0] ?>"/>
    <allow-access-from domain="<?= $_[1] ?>" to-ports="<?= $_[2] ?>"/>
</cross-domain-policy>
?= "\0"
__TEMPLATE__

enum CrossDomainPolicies => qw(all none master-only);

has permitted_cross_domain_policies => (
    is => 'rw',
    isa => 'CrossDomainPolicies',
    trigger => \&_create_policy,
);

has domain   => (
    is => 'rw',
    isa => 'Str',
    trigger => \&_create_policy,
);

has to_ports => (
    is => 'rw',
    isa => 'Str',
    trigger => \&_create_policy,
);

has port => (
    is => 'rw',
    isa => 'Int',
    default => LISTEN_PORT,
);

has policy   => (
    is => 'rw',
    isa => 'Str',
);

sub _create_policy {
    my $self = shift;;
    my $template = TEMPLATE;
    my $policy   = render_mt( $template, $self->permitted_cross_domain_policies,
        $self->domain, $self->to_ports )->as_string;
    $self->policy($policy);
}

sub _create_tcp_server {
    my $self = shift;
    return tcp_server undef, $self->port, $self->_create_accept_handler();
}

sub _create_accept_handler {
    my $self = shift;
    return sub {
        my ($sock, $host, $port) = @_;
        DEBUG && warn "connect ${host}:${port}";

        # reading request header
        my $read_guard;
        $read_guard = AE::io $sock, 0, sub {
            DEBUG && warn 'read start...';
            my $data = '';
            my $rlen = read $sock, $data, 100, 0;
            DEBUG && warn "result: length=${rlen} data=${data}";
            if ( !defined $rlen || $data ne POLICY_REQUEST ) {
                DEBUG && warn 'Cannnot read request.';
                undef $read_guard;
                return;
            }

            DEBUG && warn 'policy-file-request';
            $self->_write($sock)->cb(
                sub {
                    shutdown $sock, 1;
                    local $@;
                    eval { $_[0]->recv; 1 } or croak 'die...';
                }
            );
            undef $read_guard;
        };

        # setting TCP_NODELAY for prohibit NAGLE algorithm
        try {
            setsockopt $sock, IPPROTO_TCP, TCP_NODELAY, 1;
            DEBUG && warn "setting tcp_nodelay";
        }
        catch {
            DEBUG && warn "Failed setting tcp_nodelay";
        }
    };
}

sub _write {
    my($self, $sock) = @_;
    my $ret = AE::cv;
    my $handle = AnyEvent::Handle->new( fh => $sock );
    $handle->on_error(
        sub {
            my $err = $_[2];
            $handle->destroy;
            $ret->send($err);
        }
    );
    $handle->push_write($self->policy);
    $handle->on_drain(
        sub {
            DEBUG && warn 'on_drain';
            $ret->send(1);
        }
    );
    return $ret;
}

sub run {
    my $self = shift;
    my $cv   = AE::cv;

    DEBUG && warn 'start...';

    my $listen_guard = $self->_create_tcp_server;

    $cv->recv;
}

__PACKAGE__->meta->make_immutable;

no Any::Moose;
1;

__END__

=head1 NAME

AnyEvent::FlashSocketPolicy - Asynchronous socket policy file server for a flash socket connection.

=head1 SYNOPSIS

  use AnyEvent::FlashSocketPolicy;
  my $server = AnyEvent::FlashSocketPolicy->new(
      permitted_cross_domain_policies => 'master-only',
      domain => '*',
      to_ports => '5000',
  );
  $server->run;

  Or just like this.

  % flash-socket-policy-server --domain-policy=master-only --domain='*' --to-ports=5000 &


=head1 DESCRIPTION

AnyEvent::FlashSocketPolicy is A simple Asynchronous socket policy file server with AnyEvent::Socket.

It is faster than adobe's one which using inetd, and flexibly customizable.

=head1 METHODS

=head2 new(%options)

Create flash socket policy file server.

    my $server = AnyEvent::FlashSocketPolicy->new(
        permitted_cross_domain_policies => 'master-only',
        domain => '*',
        to_ports => '5000',
    );

Available options are:

=over

=item permitted_cross_domain_policies

=item domain

=item to_ports

=item port

=item policy

=back

=head2 run

Start the server.

=head1 DEPENDENCIES

=over

=item L<Any::Moose>

=item L<AnyEvent>

=item L<AnyEvent::Handle>

=item L<AnyEvent::Socket>

=item L<Getopt::Long>

=item L<Pod::Usage>

=item L<Text::MicroTemplate>

=item L<Try::Tiny>

=back

=head1 TODO

=over

=item Logging

=item Exception handling

=item Support reading existing files.

=back

=head1 AUTHOR

keroyonn E<lt>keroyon@cpan.orgE<gt>

=head1 SEE ALSO

=over

=item L<AnyEvent::Socket>

=back

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
