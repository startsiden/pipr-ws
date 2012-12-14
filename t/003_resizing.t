use Test::More;
use strict;
use warnings;
use Data::Dumper;
use Image::Size;
use File::Temp qw/tempdir/;

use_ok 'Pipr::WS';
use Dancer::Test;

my $cache       = tempdir( 'pipr-cacheXXXX',       CLEANUP => 1, );
my $thumb_cache = tempdir( 'pipr-thumb_cacheXXXX', CLEANUP => 1, );

Pipr::WS->config->{'cache_dir'} = $cache;
Pipr::WS->config->{'plugins'}->{'Thumbnail'}->{'cache'} = $thumb_cache;

response_status_is ['GET' => '/foo'], 404, 'response status is 404 for /foo';
response_status_is ['GET' => '/resized'], 404, 'response status is 404 for /resized';
response_status_is ['GET' => '/resized/40x40'], 404, 'response status is 404 for /resized/40x40';
response_status_is ['GET' => '/test/resized/30x30/'], 404, 'response status is 404 for /test/resized/30x30/';
my $test_image_url = '/images/test.png';
my $test_image_path = "public$test_image_url";
response_status_is ['GET' => $test_image_url], 200, 'test image exists';
response_status_is ['GET' => "/test/resized/30x30/$test_image_path"], 200, "response status is 200 for /test/resized/30x30/$test_image_path";
response_status_is ['GET' => "/test/resized/30x30/non-existing-image"], 404, "non-existing image returns 404";
response_status_is ['GET' => "/test/resized/30x30/http://dghasdfguasdfhgiouasdhfguiohsdfg/non-existing-image"], 404, "non-existing remote image returns 404";

my $image;

$image = dancer_response(GET => "/test/resized/30x30/$test_image_path")->content;
is_deeply [imgsize(\$image)], [30,30,'JPG'], 'Correct resized width/height (30x30)';

$image = dancer_response(GET => "/test/resized/100x30/$test_image_path")->content;
is_deeply [imgsize(\$image)], [100,30,'JPG'], 'Correct resized width/height (100x30)';

$image = dancer_response(GET => "/test/resized/30x/$test_image_path")->content;
is_deeply [imgsize(\$image)], [30,24,'JPG'], 'Correct resized width/height (30x(24))';

$image = dancer_response(GET => "/test/resized/x30/$test_image_path")->content;
is_deeply [imgsize(\$image)], [38,30,'JPG'], 'Correct resized width/height ((38)x30)';

response_status_is ['GET' => "/test/resized/30x30/https://www.google.com/images/srpr/logo3w.png"], 403, "not able to fetch illegal images";

done_testing;
