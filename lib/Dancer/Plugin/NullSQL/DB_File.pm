package Dancer::Plugin::NullSQL::DB_File;
{
  $Dancer::Plugin::NullSQL::DB_File::VERSION = '0.01';
}
 
use strict;
use warnings;
 
use 5.008;
 
use Dancer ':syntax';
use Dancer::Plugin;
 
use DB_File;
my $buckets = {};
{
    use Data::Dumper;
    warn Dumper(plugin_setting);
    my $file  = plugin_setting->{'basepath'};
    die "No basepath for DB_File in settings" if (!$file);
}

sub mk_bucket {
    my ($bucket, $set) = @_;
    my $base  = $set->{'basepath'};
    $base   //= '/tmp/dancer-plugin-db_file';
    $base    .= "-$bucket" if ($bucket);
    my %dbfile;
    dbmopen(%dbfile, $base, 0666) || die "dbmopen $base failed: $!";
    return \%dbfile;
}

=head2 db_set($key, $value)

Store value in database with key
 
=cut
 
register db_set => sub {
    my($self, $bucket, $key, $value) = plugin_args(@_);
    if (!$buckets->{$bucket}) {
        $buckets->{$bucket} = mk_bucket($bucket, plugin_setting);
    }
    
    return $buckets->{$bucket}->{$key} = $value;
};
 
=head2 db_get($key)
 
Grab a specified key. Returns undef if the key is not found.
 
=cut
 
register db_get => sub
{
    my($self, $bucket, $key) = plugin_args(@_);

    if (!$buckets->{$bucket}) {
        warn "Bucket $bucket does not exist";
        return undef;
    }
    
    return $buckets->{$bucket}->{$key}
};
 
 
register_plugin;
