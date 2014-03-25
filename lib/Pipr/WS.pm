package Pipr::WS;
use v5.10;

use Dancer;
use Dancer::Config;
use Dancer::Plugin::Thumbnail;

#use Dancer::Plugin::ConfigJFDI;
use Data::Dumper;
use Encode;
use File::Slurp;
use File::Share ':all';
use File::Spec;
use File::Type;
use HTML::TreeBuilder;
use Image::Size;
use LWPx::ParanoidAgent;
use LWP::UserAgent::Cached;
use List::Util;
use Digest::MD5 qw(md5_hex);
use File::Spec;
use File::Path;
use Net::DNS::Resolver;
use Cwd;
use URI;
use URI::Escape;

our $VERSION = '14.13.6';

my $ua = LWPx::ParanoidAgent->new();
$ua->whitelisted_hosts( @{ config->{whitelisted_hosts} } );
$ua->timeout(10);
$ua->resolver( Net::DNS::Resolver->new() );

my $local_ua = LWP::UserAgent->new();
$local_ua->protocols_allowed( ['file'] );

set 'appdir' => eval { dist_dir('Pipr-WS') } || File::Spec->catdir(config->{appdir}, 'share');

set 'confdir' => File::Spec->catdir(config->{appdir});

set 'envdir'  => File::Spec->catdir(config->{appdir}, 'environments');
set 'public'  => File::Spec->catdir(config->{appdir}, 'public');
set 'views'   => File::Spec->catdir(config->{appdir}, 'views');

Dancer::Config::load();

get '/' => sub {
    template 'index' => { sites => config->{sites} } if config->{environment} ne 'production';
};

get '/*/dims/**' => sub {
    my ( $site, $url ) = splat;

    $url = get_url($url);

    my $local_image = get_image_from_url($url);
    my ( $width, $height, $type ) = Image::Size::imgsize($local_image);

    content_type 'application/json';
    return to_json {
        image => { type => lc $type, width => $width, height => $height }
    };
};

get '/*/*/*/**' => sub {
    my ( $site, $cmd, $params, $url ) = splat;

    $url = get_url($url);

    return do { debug 'no site set';    status 'not_found' } if !$site;
    return do { debug 'no command set'; status 'not_found' } if !$cmd;
    return do { debug 'no params set';  status 'not_found' } if !$params;
    return do { debug 'no url set';     status 'not_found' } if !$url;

    my $site_config = config->{sites}->{ $site };
    $site_config->{site} = $site;
    if (config->{restrict_targets}) {
      return do { debug "illegal site: $site";   status 'not_found' } if ! $site_config;
    }
    var 'site_config' => $site_config;

    my ( $format, $offset ) = split /,/, $params;
    my ( $x,      $y )      = split /x/, $offset || '0x0';
    my ( $width,  $height ) = split /x/, $format;

    if ( config->{restrict_targets} ) {
        debug "checking '$url' with '$params'";
        return do { debug 'no matching targets'; status 'forbidden' }
          if !List::Util::first { $url =~ m{\A \Q$_\E   }gmx; }
            @{ $site_config->{allowed_targets} };
        return do { debug 'no matching sizes'; status 'forbidden' }
          if !List::Util::first { $format =~ m{\A \Q$_\E \z}gmx; }
            @{ $site_config->{sizes} };
    }

    my $local_image = get_image_from_url($url);
    return do { debug "unable to download picture: $url"; status 'not_found' }
      if !$local_image;

    my $thumb_cache = File::Spec->catdir(config->{plugins}->{Thumbnail}->{cache}, $site);

    given ($cmd) {
        when ('resized') {
            return resize $local_image => {
                w => $width, h => $height, s => 'force'
            },
            {
                format => 'jpeg', quality => '90', cache => $thumb_cache
            }
        }
        when ('cropped') {
            return thumbnail $local_image => [
                crop => {
                    w => $width + $x, h => $height + $y, a => 'lt'
                },
                crop => {
                    w => $width, h => $height, a => 'rb'
                },
              ],
            {
                format => 'jpeg', quality => '90', cache => $thumb_cache
            };
        }
        when ('thumbnail') {
            return thumbnail $local_image => [
                crop => {
                    w => 200, h => 200, a => 'lt'
                },
                resize => {
                    w => $width, h => $height, s => 'min'
                },
              ],
            {
                format => 'jpeg', quality => 90, cache => $thumb_cache
            };
        }
        default {
            return do { debug 'illegal command'; status '401'; }
        }
    }
};

sub get_image_from_url {
    my ($url) = @_;

    my $local_image = download_url($url);
    my $ft          = File::Type->new();

    return if !$local_image;
    return if !-e $local_image;

    return $local_image
      if ( $ft->checktype_filename($local_image) =~ m{ \A image }gmx );

    debug "fetching image from '$local_image'";

    my $res = $local_ua->get("file:$local_image");

    my $tree = HTML::TreeBuilder->new_from_content( $res->decoded_content );

    my $ele = $tree->find_by_attribute( 'property', 'og:image' );
    my $image_url = $ele && $ele->attr('content');

    if ( !$image_url ) {
        $ele = $tree->look_down(
            '_tag' => 'img',
            sub {
                debug "$url: " . $_[0]->as_HTML;
                ( $url =~ m{ dn\.no | nettavisen.no }gmx
                      && defined $_[0]->attr('title') )
                  || ( $url =~ m{ nrk\.no }gmx && $_[0]->attr('longdesc') );
            }
        );
        $image_url = $ele && $ele->attr('src');
    }

    if ($image_url) {
        my $u = URI->new_abs( $image_url, $url );
        $image_url = $u->canonical;
        debug "fetching: $image_url instead from web page";
        $local_image = download_url( $image_url, $local_image, 1 );
    }

    return $local_image;
}

sub download_url {
    my ( $url, $local_file, $ignore_cache ) = @_;

    my $site_config = var 'site_config';

    debug config;
    debug "downloading url: $url";

    $url =~ s{^(https?):/(?:[^/])}{$1/}mx;

    if ($url !~ m{ \A (https?|ftp)}gmx) {
        if ( config->{allow_local_access} ) {
            my $local_file = File::Spec->catfile( config->{appdir}, $url );
            debug "locally accessing $local_file";
            return $local_file if $local_file;
        }

        if ($site_config->{prefix}) { 
            $url =~ s{\A / }{}gmx;
            $url = $site_config->{prefix} . "/$url";
        }

    }

    $local_file ||= File::Spec->catfile(
        (
            File::Spec->file_name_is_absolute( config->{'cache_dir'} )
            ? ()
            : config->{appdir}
        ),
        config->{'cache_dir'},
        $site_config->{site},
        _url2file($url)
    );

    File::Path::make_path( dirname($local_file) );

    debug 'local_file: ' . $local_file;

    return $local_file if !$ignore_cache && -e $local_file;

    debug 'fetching from the net...';

    my $res = eval { $ua->get($url, ':content_file' => $local_file); }; 
    debug $res->status_line unless ($res && $res->is_success);

    # Try fetching image from HTML page

    return (($res && $res->is_success) ? $local_file : ($res && $res->is_success));
}

sub get_url {
    my ($url) = @_;

    # if we get an URL like: http://pipr.opentheweb.org/overblikk/resized/300x200/http://g.api.no/obscura/external/9E591A/100x510r/http%3A%2F%2Fnifs-cache.api.no%2Fnifs-static%2Fgfx%2Fspillere%2F100%2Fp1172.jpg
    # We want to re-escape the external URL in the URL (everything is unescaped on the way in)
    $url = join '/', @{$url};
    $url =~ s{ \A (.+) (http://.*) \z }{ $1 . URI::Escape::uri_escape($2)}ex;

    my $rparams    = params();
    my $str_params = join "&", map { "$_=" . $rparams->{$_} } grep { $_ ne 'splat' } keys %{$rparams};
    $url = join "?", ( $url, $str_params ) if $str_params;

    return $url;
}

sub _url2file {
    my ($url) = @_;

  my $md5 = md5_hex(encode_utf8($url));
  my @parts = ( $md5 =~ m/^(.)(..)/ );
  $url =~ s/[^A-Za-z0-9_\-\.=?,()\[\]\$^:]/_/gmx;

  File::Spec->catfile(@parts,$url);
}

true;

=pod

=head1 AUTHOR
 
   Nicolas Mendoza <mendoza@pvv.ntnu.no>

=head1 ABSTRACT

   Picture Proxy/Provider/Presenter

=cut

