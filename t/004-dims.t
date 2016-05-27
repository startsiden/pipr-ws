#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Data::Dumper;
use File::Temp qw/tempdir/;
use Image::Size;
use JSON;
use Test::More;

# The order is important
use_ok 'Pipr::WS';
use Dancer::Test;

my $test_image_path = "public/images/test.png";

is_deeply(
  from_json(dancer_response('GET' => "/test/dims/$test_image_path")->content),
  { image => { width => 1280, height => 1024, type => 'png' } },
  'Check that dimensions are correct'
);

done_testing;
