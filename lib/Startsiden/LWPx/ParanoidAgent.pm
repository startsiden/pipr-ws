package Startsiden::LWPx::ParanoidAgent;

use strict;
use warnings;

use base 'LWPx::ParanoidAgent';

use Cache::LRU;

our $cache = Cache::LRU->new( size => 1000 );
our $cache_ttl = 60;

sub _resolve {
    my ($self, $host, $request, $timeout, $depth) = @_;

    my $cache_key = $host;

    if (my $value = $cache->get($cache_key)) {
        my ($res, $expires_at) = @$value;
        return @{ $res } if time < $expires_at;
        $cache->remove($cache_key);
    }
    my @res = $self->SUPER::_resolve($host, $request, $timeout, $depth);
   
    $cache->set(
        $cache_key => [ [ @res ], time + $cache_ttl + 0.5 ],
    );

    return @res;
}
