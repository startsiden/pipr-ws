use Test::More;
use strict;
use warnings;
use Data::Dumper;
use Image::Size;
use File::Temp qw/tempdir/;
use JSON;
use File::Slurp;

use_ok 'Pipr::WS';

use Dancer::Test;

my $test_image_path = "public/images/test.png";

my $res = dancer_response('GET' => "/test/p/$test_image_path");

is($res->header('Content-Type'), 'image/x-png', 'Correct MIME-Type');

my $proxied_file = $res->content;
my $orig_file = File::Slurp::read_file("share/$test_image_path", binmode => ':raw');
is($proxied_file, $orig_file, 'Files are identical');

done_testing;
