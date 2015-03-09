use warnings;
use strict;

use Pipr::WS;
use Test::More;

my $tests = {
  'dev.pipr.startsiden.no' => 'dev',
  'kua.pipr.startsiden.no' => 'kua',
  'kua.lol.no'             => 'www',
  'qa.pipr.startsiden.no'  => 'www',
  'localhost'              => 'www',
};

while (my ($host, $subdomain) = each %{$tests}) {
    is(Pipr::WS::expand_macros('%ENV_SUBDOMAIN%', $host), $subdomain, "$host => $subdomain");
}

done_testing;
