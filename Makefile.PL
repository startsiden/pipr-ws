use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Pipr::WS',
    AUTHOR              => q{Nicolas Mendoza <mendoza@pvv.ntnu.no>},
    VERSION_FROM        => 'lib/Pipr/WS.pm',
    ABSTRACT            => 'Picture Proxy/Provider/Presenter',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer'     => 1.3110,
        'Dancer::Plugin::Thumbnail' => 0,
           'GD' => 0,
           'JSON::Any' => 0,
           'List::Util' => 0,
           'Object::Signature' => 0,
           'POSIX' => 0,
        'File::Type' => 0,
        'LWPx::ParanoidAgent' => 0,
        'LWP::UserAgent::Cached' => 0,
        'Net::DNS::Resolver' => 0,
        'Image::Size' => 0,
        'HTML::TreeBuilder' => 0,
        'File::Slurp' => 0,
        'Template::Plugin::DataPrinter' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Pipr-WS-*' },
);
