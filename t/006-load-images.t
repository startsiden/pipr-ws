#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use File::Spec::Functions;
use FindBin;
use Test::More;
use Image::Magick;

my $im = Image::Magick->new;

my %testfiles = (
    'valid.jpg' => 'JPEG',
    'gd.jpg'    => 'JPEG',    # A valid JPEG which GD does not recognize (see ABCN-5122)
    'valid.png' => 'PNG',
    'valid.gif' => 'GIF'
);

subtest 'Verify that images are loaded correctly' => sub {
    for my $file ( keys %testfiles ) {
        my $image = catfile( $FindBin::Bin, 'data', $file );
        my $format = ( $im->Ping($image) )[3];
        is( $format, $testfiles{$file}, "Image is $testfiles{$file}" );
    }
};

done_testing;
