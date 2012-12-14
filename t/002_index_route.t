use Test::More tests => 3;
use strict;
use warnings;

# the order is important
use_ok 'Pipr::WS';
use Dancer::Test;

route_exists [GET => '/'], 'a route handler is defined for /';
response_status_is ['GET' => '/'], 200, 'response status is 200 for /';

map { warn $_->{message} if $_->{level} eq 'error'; } @{ &read_logs };
