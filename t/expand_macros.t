#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Pipr::WS;
use Test::More;

my $tests = {
  'dev.pipr.startsiden.no'  => 'dev',
  'dev-pipr.startsiden.dev' => 'dev',
  'kua.pipr.startsiden.no'  => 'kua',
  'kua-pipr.startsiden.no'  => 'kua',
  'qa.pipr.startsiden.no'   => 'kua',
  'qa-pipr.startsiden.no'   => 'kua',
  'pipr-ws1.startsiden.no'  => 'www',
  'kua.lol.no'              => 'www',
  'localhost'               => 'www',
};

while (my ($host, $subdomain) = each %{$tests}) {
    is(Pipr::WS::expand_macros('%ENV_SUBDOMAIN%', $host), $subdomain, "$host => $subdomain");
}

done_testing;
