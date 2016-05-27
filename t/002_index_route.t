#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Test::More;

# The order is important
use_ok 'Pipr::WS';
use Dancer::Test;

route_exists [GET => '/'], 'a route handler is defined for /';

response_status_is ['GET' => '/'], 200, 'response status is 200 for /';

map { warn $_->{message} if $_->{level} eq 'error'; } @{ &read_logs };

done_testing;
