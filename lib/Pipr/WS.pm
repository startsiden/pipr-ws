package Pipr::WS;
use v5.10;

use Dancer;
use Dancer::Plugin::Thumbnail;
#use Dancer::Plugin::ConfigJFDI;
use Data::Dumper;
use Encode;
use LWPx::ParanoidAgent;
use LWP::UserAgent::Cached;
use List::Util;
use Digest::MD5 qw(md5_hex);
use File::Spec;
use File::Path;
use Net::DNS::Resolver;
use Cwd;

our $VERSION = '0.1';

get '/' => sub {
    template 'index' => { sites => config->{sites} };
};

get '/*/*/*/**' => sub {
  my ($site, $cmd, $params, $url) = splat;
    $url = join '/', @{ $url };
    return do { debug 'no site set';    status 'not_found' } if ! $site;
    return do { debug 'no command set'; status 'not_found' } if ! $cmd;
    return do { debug 'no params set';  status 'not_found' } if ! $params;
    return do { debug 'no url set';     status 'not_found' } if ! $url;

#    FIXME: Support URLs with GET params
#    my $rparams = params();
#    delete $rparams->{splat};

#    $url = join '?', ($url, (join '&', map { $_ . '=' . $rparams->{$_}; } keys %{$rparams}));

    my $site_config = config->{sites}->{ $site };
    if (config->{restrict_targets}) {
      return do { debug "illegal site: $site";   status 'not_found' } if ! $site_config;
    }
    var 'site_config' => $site_config;

    my ($format, $offset) = split /,/, $params;
    my ($x, $y)           = split /x/, $offset || '0x0';
    my ($width, $height)  = split /x/, $format;

    if (config->{restrict_targets}) {
      debug "checking '$url' with '$params'";
      return do { debug 'no matching targets'; status 'forbidden' } if ! List::Util::first { $url    =~ m{\A \Q$_\E   }gmx; } @{ $site_config->{allowed_targets} };
      return do { debug 'no matching sizes';   status 'forbidden' } if ! List::Util::first { $format =~ m{\A \Q$_\E \z}gmx; } @{ $site_config->{sizes}           };
    }

    my $local_image = download_url( $url );
    return do { debug "unable to download picture: $url"; status 'not_found' } if ! $local_image;

    my $thumb_cache = config->{plugins}->{Thumbnail}->{cache};

    given ($cmd) { 
       when ('resized')   { resize    $local_image => { w => $width, h => $height, s => 'force' }, { format => 'jpeg', quality => '90', cache => $thumb_cache } }
       when ('cropped')   { thumbnail $local_image => [
           crop   => { w => $width+$x, h => $height+$y, a => 'lt' },
           crop   => { w => $width,    h => $height,    a => 'rb' },
         ],
         { format => 'jpeg', quality => '90', cache => $thumb_cache };
       }
       when ('thumbnail') { thumbnail $local_image => [
           crop   => { w => 200, h => 200, a => 'lt' },
           resize => { w => $width, h => $height, s => 'min' },
         ], 
         { format => 'jpeg', quality => 90, cache => $thumb_cache  };
       }
       default             { return do { debug 'illegal command'; status '401'; } }
    }
};


sub download_url {
  my ($url) = @_;

  my $site_config = var 'site_config';

  debug config;
  debug "downloading url: $url";

  if (config->{allow_local_access} && $url !~ m{ \A (https?|ftp) }gmx) {
     my $local_file = File::Spec->catfile(config->{appdir}, $url);
     debug "locally accessing $local_file";
     return $local_file if $local_file;
  }

  my $ua = LWPx::ParanoidAgent->new();
  $ua->whitelisted_hosts(@{ config->{whitelisted_hosts} });
  $ua->timeout(10);
  $ua->resolver(Net::DNS::Resolver->new());

  my $local_file = File::Spec->catfile((File::Spec->file_name_is_absolute(config->{'cache_dir'}) ? () : config->{appdir}), config->{'cache_dir'}, _url2file($url));

  File::Path::make_path(dirname($local_file));

  debug 'local_file: ' . $local_file;

  return $local_file if -e $local_file;

  debug 'fetching from the net...';

  my $res = $ua->get($url, ':content_file' => $local_file);
  debug $res->status_line if ! $res->is_success;

  return ($res->is_success ? $local_file : $res->is_success);
}

sub _url2file {
  my ($url) = @_;

  my $md5 = md5_hex(encode_utf8($url));
  my @parts = ( $md5 =~ m/../g );
  File::Spec->catfile(@parts);
}

true;
