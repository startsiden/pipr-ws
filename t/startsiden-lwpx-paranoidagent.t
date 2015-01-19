#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Startsiden::LWPx::ParanoidAgent;

my $ua = Startsiden::LWPx::ParanoidAgent->new();

my @res1 = $ua->_resolve("www.google.com");
sleep 1;

my ($res_cached, $expires_at) = @{ $Startsiden::LWPx::ParanoidAgent::cache->get("www.google.com") };
ok(($expires_at - time) < 60, 'cache ttl is less than 60');
ok(($expires_at - time) > 58, 'cache ttl is greater than 58');

my @res2 = $ua->_resolve("www.google.com");

is_deeply(\@res1, $res_cached, 'Same result even if cached');
is_deeply(\@res1, \@res2, 'Same result after cached');


done_testing;
