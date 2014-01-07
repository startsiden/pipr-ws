package Dancer::Plugin::NullSQL;
{
  $Dancer::Plugin::NullSQL::VERSION = '0.01';
}
 
use strict;
use warnings;
 
use 5.008;
 
use Dancer ':syntax';
use Dancer::Plugin;

eval {
    my $settings = plugin_setting;
    require "Dancer/Plugin/NullSQL/" . $settings->{driver} . ".pm";
    my $module = "Dancer::Plugin::NullSQL::" . $settings->{driver};
    $module->import();
    1;
} or do {
    warn "$@";
};

register_plugin;
