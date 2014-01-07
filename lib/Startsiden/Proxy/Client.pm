package Startsiden::Proxy::Client;
use Moose;
use LWPx::ParanoidAgent;

use HTTP::Response;
use HTTP::Headers;


has '_ua' => (
    is      => 'ro',
    isa     => 'LWPx::ParanoidAgent',
    lazy    => 1,
    builder => '_build_ua',
);

has 'proxy_url' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'http://localhost:8080',
);

has 'source' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'proxy',
);

has 'max_age' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'expire' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

# Server should refresh content after this many seconds, 0 means no refresh
has 'refresh' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

# Server can delete after this many seconds of no use, 0 uses server default
has 'delete_after' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

# Put header and response in body, separated by an extra \n
has 'in_body' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'max_stale' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'only_if_cached' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'no_cache' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'timeout' => (
    is      => 'rw',
    isa     => 'Int',
    default => 5,
);

sub _build_ua {
    my $ua = LWPx::ParanoidAgent->new;
    $ua->whitelisted_hosts("localhost", "127.0.0.1");
    $ua->default_header( agent => 'Startsiden Proxy' );
    $ua->timeout($_[0]->timeout);
    return $ua;
}

sub get {
    my ($self, $target) = @_;
    my $url = join('/', $self->proxy_url, $self->source, 'fetch', $target);
    my $res;
    $@ = "";
    $self->_ua->default_header('Cache-Control' => $self->get_cache_params);

    eval {
        $res = $self->_ua->get( $url );
    };

    if ($@ || !$res->is_success) {
        warn "request failed\n";
        return $res;
    }

    my ($headers, $content);
    if ($res->header('X-in-body')) {
        my $header;
        ($header, $content) = $res->decoded_content =~ /(.*?)\n\n(.*)/gs;
        $headers = HTTP::Headers->new;
        foreach my $l (split(/\n/, $header)) {
            my ($key, $val) = $l =~ /([^:]+):\s*(.*)/;
            $headers->header($key => $val);
        }
    } else {
        $headers = $res->headers;
        $content = $res->content;
    }
    my ($code, $message) = $headers->header('X-remote-code') =~ /(.*?) (.*)/;
    my $r = HTTP::Response->new( $code, $message, $headers, $content );
    return $r;
}

sub get_params {
    my $self = shift;
    my @params;
    foreach my $param (qw/max_age expire in_body download/) {
        push @params, "$param=" . $self->$param if ($self->$param);
    }
    return join(',', @params);
}

sub get_cache_params {
    my $self = shift;
    my @params;
    if ( $self->max_stale + $self->only_if_cached + $self->no_cache > 1) {
        warn "Only one of the options max_stale, only_if_cached and no_cache should be true\n";
    }
    foreach my $param (qw/max_age expire refresh in_body max_stale only_if_cached no_cache/) {
        next if (!$self->$param);
        my $key = $param;
        $key =~ s/_/-/g;
        if ($self->meta->get_attribute($param)->type_constraint eq 'Bool') {
            push @params, $key;
        } else {
            push @params, "$key=" . $self->$param;
        }
    }
    return join(',', @params);
}

1;
