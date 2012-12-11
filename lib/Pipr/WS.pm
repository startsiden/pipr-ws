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

our $VERSION = '0.1';

get '/' => sub {
    content_type 'text/plain';
    return Dumper(config->{sites});
};

get '/*/*/*/**' => sub {
  my ($site, $cmd, $params, $url) = splat;
    $url = join '/', @{ $url };
    return status 'not_found' if ! $site;
    return status 'not_found' if ! $cmd;
    return status 'not_found' if ! $params;
    return status 'not_found' if ! $url;

    my $site_config = config->{sites}->{ $site };
    return status 'not_found' if ! $site_config;
    var 'site_config' => $site_config;

    return status 'forbidden' if ! List::Util::first { $url    =~ m{\A \Q$_\E   }gmx; } @{ $site_config->{allowed_targets} };
    return status 'forbidden' if ! List::Util::first { $params =~ m{\A \Q$_\E \z}gmx; } @{ $site_config->{sizes}           };

    my $local_image = download_url( $url );
    return status 'not_found' if ! $local_image;

    my ($width, $height) = split /x/, $params;

    given ($cmd) { 
       when ('resized')   { resize    $local_image => { w => $width }, { format => 'jpeg', quality => '90', } }
       when ('cropped')   { crop      $local_image => { w => $width }; { format => 'jpeg', quality => '90', } }
       when ('thumbnail') { thumbnail $local_image => [
           crop   => { w => 200, h => 200, a => 'lt' },
           resize => { w => $width, h => $height, s => 'min' },
         ], 
         { format => 'jpeg', quality => 90 };
       }
       default             { return status '401'; }
    }
};


sub download_url {
  my ($url) = @_;

  my $site_config = var 'site_config';

  my $ua = LWPx::ParanoidAgent->new();
  $ua->timeout(10);
  $ua->resolver(Net::DNS::Resolver->new());
#  $ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());

#  $ua->add_handler("request_send",  sub { shift->dump; return });
#  $ua->add_handler("response_done", sub { shift->dump; return });

  my $local_file = File::Spec->catfile(config->{'cache_dir'}, _url2file($url));

  File::Path::make_path(File::Basename::dirname($local_file));
  debug File::Basename::dirname($local_file);
  debug $url;

  return $local_file if -e $local_file;
  return $ua->get($url, ':content_file' => $local_file);
}

sub _url2file {
  my ($url) = @_;

  my $md5 = md5_hex($url);
  my @parts = ( $md5 =~ m/../g );
  File::Spec->catfile(@parts);
}


true;
