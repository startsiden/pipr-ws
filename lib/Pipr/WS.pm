package Pipr::WS;
use v5.10;

use Dancer;
use Dancer::Exception::Core::Request;
use Dancer::Plugin::Thumbnail;
use Data::Dumper;
use LWPx::ParanoidAgent;
use LWP::UserAgent::Cached;
use List::Util;
use Digest::MD5 qw(md5_hex);
use File::Spec;
use File::Path;
use File::Basename;
use Net::DNS::Resolver;
use Cwd;

our $VERSION = '0.1';

get '/' => sub {
    content_type 'text/plain';
    return Dumper(config->{sites});
};

get '/*/*/*/**' => sub {
  my ($site, $cmd, $params, $url) = splat;
    $url = join '/', @{ $url };
    return do { debug 'no site set';    status 'not_found' } if ! $site;
    return do { debug 'no command set'; status 'not_found' } if ! $cmd;
    return do { debug 'no params set';  status 'not_found' } if ! $params;
    return do { debug 'no url set';     status 'not_found' } if ! $url;

    my $site_config = config->{sites}->{ $site };
    return do { debug 'illegal site';   status 'not_found' } if ! $site_config;
    var 'site_config' => $site_config;

    debug "checking '$url' with '$params'";
    return do { debug 'no matching targets'; status 'forbidden' } if ! List::Util::first { $url    =~ m{\A \Q$_\E   }gmx; } @{ $site_config->{allowed_targets} };
    return do { debug 'no matching sizes';   status 'forbidden' } if ! List::Util::first { $params =~ m{\A \Q$_\E \z}gmx; } @{ $site_config->{sizes}           };

    my $local_image = download_url( $url );
    return do { debug 'unable to download picture'; status 'not_found' } if ! $local_image;

    my ($width, $height) = split /x/, $params;

    given ($cmd) { 
       when ('resized')   { resize    $local_image => { w => $width, h => $height, s => 'force' }, { format => 'jpeg', quality => '90', } }
       when ('cropped')   { crop      $local_image => { w => $width }; { format => 'jpeg', quality => '90', } }
       when ('thumbnail') { thumbnail $local_image => [
           crop   => { w => 200, h => 200, a => 'lt' },
           resize => { w => $width, h => $height, s => 'min' },
         ], 
         { format => 'jpeg', quality => 90 };
       }
       default             { return do { debug 'illegal command'; status '401'; } }
    }
};


sub download_url {
  my ($url) = @_;

  my $site_config = var 'site_config';

  debug config;

  if (config->{allow_local_access}) {
     my $local_file = File::Spec->catfile(config->{appdir}, $url);
     debug "locally accessing $local_file";
     return $local_file if $local_file;
  }

  my $ua = LWPx::ParanoidAgent->new();
  $ua->whitelisted_hosts(@{ config->{whitelisted_hosts} });
  $ua->timeout(10);
  $ua->resolver(Net::DNS::Resolver->new());

  my $local_file = File::Spec->catfile(config->{'cache_dir'}, _url2file($url));

  File::Path::make_path(File::Basename::dirname($local_file));
  debug 'dirname: ' . File::Basename::dirname($local_file);
  debug 'url: ' . $url;

  return $local_file if -e $local_file;
  my $res = $ua->get($url, ':content_file' => $local_file);
  if ($res->is_success) {
    print $res->content;  # or whatever
  }
  else {
    die $res->status_line;
  }
}

sub _url2file {
  my ($url) = @_;

  my $md5 = md5_hex($url);
  my @parts = ( $md5 =~ m/../g );
  File::Spec->catfile(@parts);
}


true;
