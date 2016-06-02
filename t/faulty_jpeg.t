#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use GD::Image;
use Test::More;

local $TODO = 'This fails with libgd2 2.036 in wheezy';
ok(GD::Image->new('t/data/nordkapp_to.jpg'), 'Able to load problematic JPG');
ok(GD::Image->new('t/data/vannings980.jpg'), 'Able to load problematic JPG');

done_testing;
