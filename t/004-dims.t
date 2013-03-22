use Test::More;
use strict;
use warnings;
use Data::Dumper;
use Image::Size;
use File::Temp qw/tempdir/;
use JSON;

use_ok 'Pipr::WS';

use Dancer::Test;

my $test_image_path = "public/images/test.png";

is_deeply(
  from_json(dancer_response('GET' => "/test/dims/$test_image_path")->content),
  { image => { width => 1280, height => 1024, type => 'png' } }, 
  'Check that dimensions are correct'
);

done_testing;
