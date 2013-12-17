package Pipr::WS;
use v5.10;

use Dancer;
use Dancer::Plugin::Thumbnail;

#use Dancer::Plugin::ConfigJFDI;
use Data::Dumper;
use Encode;
use File::Slurp;
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
use MIME::Base64 qw(encode_base64);
# If Riak is not available, uncomment DB_File and comment Riak
#use Dancer::Plugin::NullSQL::DB_File;
use Dancer::Plugin::NullSQL::Riak;

our $VERSION = '0.1';

my $ua = LWPx::ParanoidAgent->new();
$ua->whitelisted_hosts( @{ config->{whitelisted_hosts} } );
$ua->timeout(10);
$ua->resolver( Net::DNS::Resolver->new() );

my $local_ua = LWP::UserAgent->new();
$local_ua->protocols_allowed( ['file'] );

#use GDBM_File; # Need to use this because unlike the others it has no size limit
use DB_File;
my %data_storage;
dbmopen(%data_storage,'/tmp/pipr-ws-data',0666);
my %meta_storage;
dbmopen(%meta_storage,'/tmp/pipr-ws-meta',0666);

get '/' => sub {
    template 'index' => { sites => config->{sites} };
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

get '/*/fetch/**' => sub {
    my ($site, $url) = splat;
    
    config->{charset} = '';
    $url = get_url($url);
    my $config = {
        download => 20,
        max_age  => 60,
        refresh  =>  0,
        expire   => 3600*24,
        site     => $site,
        url      => $url,
        in_body  =>  0,
        };
    _merge_config( $config, config->{sites}->{ 'default' } );
    _merge_config( $config, config->{sites}->{ $site } );
    _merge_config( $config, _get_cache_params(request->header('Cache-Control')) );
    
    my ($head, $content) = fetch_url($url, $config);
    header 'X-in-body' => $config->{in_body};

    if ($config->{in_body}) {
        header 'Content-type' => 'application/octet-stream';
        return $head . "\n" . $content;
    } else {
        foreach my $l (split/\n/, $head) {
            my ($key, $val) = $l =~ /([^:]+):\s*(.*)/;
            header $key => $val;
        }
        return $content;
    }
};

sub fetch_url {
    my ($url, $conf) = @_;
    my $content;
    my $meta = {};
    my $hash = md5_hex($url);

    # values for $download:
    # 0 = only-if-cached (never download)
    # 1 = max-stale      (download only if there is nothing in cache)
    # 2 = default        (download if cached content is too old)
    # 3 = no-cache       (always download)
    my $download = 2;
    $download = 0 if $conf->{only_if_cached};
    $download = 1 if $conf->{max_stale};
    $download = 3 if $conf->{no_cache};

    if ($download < 3) {
        $meta = get_meta($hash);
    }

    # Fetch url
    if ($download >= 1
        && ( ! defined($meta->{max_age})
            || ($download >= 2 && $meta->{last_fetched} + $meta->{max_age} < time)
            || $download >= 3
           ) ) {
        debug "Getting from source";
        my $res = $ua->get( $url );
        if ($res->is_success) {
            $content = $res->decoded_content;
            $meta->{head} = $res->headers->as_string;
            $meta->{head} .= 'X-remote-code: ' . $res->code . ' ' . $res->message . "\n";
        }
    }

    # Store header and body separately to avoid saving body when it's the same?    
    if (defined($content)) {
        my $md5sum = md5_hex(encode_utf8($content));
        if (!defined($meta->{md5sum}) || $md5sum ne $meta->{md5sum}) {
            debug "storing new or updated content";
            $meta->{md5sum} = $md5sum;
            set_cached($hash, $content);
        }
        $meta->{last_fetched} = time;
    } else {
        # Get cached
        debug "Using cached";
        $content = get_cached($hash);
    }
    
    # Save meta data
    foreach my $c (qw/max_age expire refresh site/) {
        $meta->{$c} = $conf->{$c} if ($conf->{$c});
    }
    $meta->{last_used} = time;
    $meta->{url} = $url;
    set_meta($hash, $meta);
    
    return ($meta->{head}, $content);
}

sub get_meta {
    my $hash = shift;
    my $data = db_get('meta', $hash);

    if ($data) {
        $data = from_json($data);
        foreach my $key (keys %$data) {
            $data->{$key} = decode_utf8($data->{$key});
        }
    } else {
        $data = {};
    }
    return $data;
}

sub set_meta {
    my ($hash, $data) = @_;
    $data = encode_utf8(to_json($data));
    db_set('meta', $hash, $data);
}

sub get_cached {
    my $hash = shift;
    return db_get('content', $hash);
}

sub set_cached {
    my ($hash, $data) = @_;
    db_set('content', $hash, $data);
}
 
get '/*/*/*/**' => sub {
    my ( $site, $cmd, $params, $url ) = splat;

    $url = get_url($url);

    return do { debug 'no site set';    status 'not_found' } if !$site;
    return do { debug 'no command set'; status 'not_found' } if !$cmd;
    return do { debug 'no params set';  status 'not_found' } if !$params;
    return do { debug 'no url set';     status 'not_found' } if !$url;

    my $site_config = config->{sites}->{$site};
    if ( config->{restrict_targets} ) {
        return do { debug "illegal site: $site"; status 'not_found' }
          if !$site_config;
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

    my $thumb_cache = config->{plugins}->{Thumbnail}->{cache};

    given ($cmd) {
        when ('resized') {
            resize $local_image => {
                w => $width, h => $height, s => 'force'
            },
            {
                format => 'jpeg', quality => '90', cache => $thumb_cache
            }
        }
        when ('cropped') {
            thumbnail $local_image => [
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
            thumbnail $local_image => [
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

    if ( config->{allow_local_access} && $url !~ m{ \A (https?|ftp) }gmx ) {
        my $local_file = File::Spec->catfile( config->{appdir}, $url );
        debug "locally accessing $local_file";
        return $local_file if $local_file;
    }

    $local_file ||= File::Spec->catfile(
        (
            File::Spec->file_name_is_absolute( config->{'cache_dir'} )
            ? ()
            : config->{appdir}
        ),
        config->{'cache_dir'},
        _url2file($url)
    );

    File::Path::make_path( dirname($local_file) );

    debug 'local_file: ' . $local_file;

    return $local_file if !$ignore_cache && -e $local_file;

    debug 'fetching from the net...';

    my $res = $ua->get( $url, ':content_file' => $local_file );
    debug $res->status_line if !$res->is_success;

    # Try fetching image from HTML page

    return ( $res->is_success ? $local_file : $res->is_success );
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

    my $md5 = md5_hex( encode_utf8($url) );
    my @parts = ( $md5 =~ m/../g );
    File::Spec->catfile(@parts);
}

sub _get_params {
    my ($params) = @_;
    
    my @params = split/,/, $params;
    my $config = {};
    
    foreach my $param (@params) {
        if ($param =~ /([^=]*)=(.*)/) {
            $config->{$1} = $2;
        } else {
            debug "_get_params could not parse parameter $param\n";
        }
    }
    return $config;
}

sub _get_cache_params {
    my ($params) = @_;
    
    my @params = split/,\s*/, $params;
    my $config = {};
    
    foreach my $param (@params) {
        if ($param =~ /([^=]*)=(.*)/) {
            my ($key, $val) = ($1, $2);
            $key =~ s/-/_/g;
            $config->{$key} = $val;
        } else {
            $param =~ s/-/_/g;
            $config->{$param} = 1;
        }
    }
    return $config;
}

sub _merge_config {
    my $target = shift;
    foreach my $source (@_) {
        if (ref($source) eq "HASH") {
            while (my ($k, $v) = each %$source) {
                $target->{$k} = $v;
            }
        } elsif(defined($source)) {
            debug "non hash parameter to _merge_config: " . Dumper($source);
        }
    }
    return 1;
}

true;
