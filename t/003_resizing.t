use Test::More tests => 6;
use strict;
use warnings;

use_ok 'Pipr::WS';
use Dancer::Test;

response_status_is ['GET' => '/foo'], 404, 'response status is 404 for /foo';
response_status_is ['GET' => '/resized'], 404, 'response status is 404 for /resized';
response_status_is ['GET' => '/resized/40x40'], 404, 'response status is 404 for /resized/40x40';
response_status_is ['GET' => '/hvordan/resized/30x30/'], 404, 'response status is 404 for /hvordan/resized/30x30/';
response_status_is ['GET' => '/hvordan/resized/30x30/http://localhost'], 403, 'response status is 403 for /hvordan/resized/30x30/http://localhost';
