#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use File::Spec::Functions;
use FindBin;
use Image::Info qw/image_type/;
use Test::More;

my %testfiles = (
    'valid.jpg' => 'JPEG',
    'gd.jpg'    => 'JPEG',    # A valid JPEG which GD does not recognize (see ABCN-5122)
    'valid.png' => 'PNG',
    'valid.gif' => 'GIF'
);

subtest 'Verify that images are loaded correctly' => sub {
    for my $file ( keys %testfiles ) {
        my $image = catfile( $FindBin::Bin, 'data', $file );
        my $image_type = image_type($image);
        ok( !exists $image_type->{error}, 'No errors when determining image type' );
        my $file_type = $image_type->{file_type};
        is( $file_type, $testfiles{$file}, "Image is $testfiles{$file}" );
    }
};

done_testing;
