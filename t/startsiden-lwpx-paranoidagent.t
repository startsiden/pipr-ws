#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Startsiden::LWPx::ParanoidAgent;

my $ua = Startsiden::LWPx::ParanoidAgent->new();

my @res1 = $ua->_resolve("www.google.com");
sleep 1;

my ($res_cached, $expires_at) = @{ $Startsiden::LWPx::ParanoidAgent::cache->get("www.google.com") };
ok(($expires_at - time) < ( 60 * 60 * 24 ), 'cache ttl is less than (60 * 60 * 24): ' . ($expires_at - time));
ok(($expires_at - time) > ( (60 * 60 * 24) - 2 ), 'cache ttl is greater than ((60 * 60 * 24) - 2): ' . ($expires_at - time));

my @res_after_cached = $ua->_resolve("www.google.com");

is_deeply(\@res1, $res_cached, 'Same result even if cached');
is_deeply(\@res1, \@res_after_cached, 'Same result after cached');

$Startsiden::LWPx::ParanoidAgent::cache->clear();
$Startsiden::LWPx::ParanoidAgent::cache_ttl = 1;
my @res2 = $ua->_resolve("www.google.com");
my ($res_cached2, $expires_at2) = @{ $Startsiden::LWPx::ParanoidAgent::cache->get("www.google.com") };
sleep 1;
ok(($expires_at2 - time) < 1, 'cache ttl is less than 1:' . ($expires_at2 - time));

$Startsiden::LWPx::ParanoidAgent::cache_ttl = 60;
sleep 1;
my @res3 = $ua->_resolve("www.google.com");
my ($res_cached3, $expires_at3) = @{ $Startsiden::LWPx::ParanoidAgent::cache->get("www.google.com") };
ok(($expires_at3 - time) > 58, 'cache ttl is greater than 58:' .($expires_at3 - time));


done_testing;
