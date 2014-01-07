package Dancer::Plugin::NullSQL::Riak;
{
  $Dancer::Plugin::NullSQL::Riak::VERSION = '0.01';
}
 
use strict;
use warnings;
 
use 5.008;
 
use Dancer ':syntax';
use Dancer::Plugin;
use Net::Riak;

my $riak;
=head2 db_set($key, $value)

Store value in database with key
 
=cut

register db_set => sub {
    my($self, $bucket, $key, $value) = plugin_args(@_);
    if ( !$riak || !$riak->is_alive() ) {
        my $settings = plugin_setting;
        $riak = Net::Riak->new( %{ $settings } );
    }
    my $b = $riak->bucket($bucket);
    my $obj = $b->new_object($key, $value);
    $obj->content_type("application/octet-stream");
    $obj->store;
};
 
=head2 db_get($key)
 
Grab a specified key. Returns undef if the key is not found.
 
=cut
 
register db_get => sub
{
    my($self, $bucket, $key) = plugin_args(@_);
    if ( !$riak || !$riak->is_alive() ) {
        my $settings = plugin_setting;
        $riak = Net::Riak->new( %{ $settings } );
    }
    my $b = $riak->bucket($bucket);
    my $obj = $b->get($key);
    if ($obj && $obj->data) {
        return $obj->data;
    } else {
        warn "got no object data";
    }
    return undef;
};

register_plugin;
