use inc::Module::Install;

name 'Pipr::WS';

# These override things fetched by 'all_from' below.
# They must come *before* the call to 'all_from'.
perl_version '5.010001';
license 'proprietary'; # the license type ('all_from' needs this)

all_from 'lib/Pipr/WS.pm';

configure_requires 'Module::Install' => 0;

# Perl modules needed for running the tests
test_requires 'Test::More';

# Perl modules needed at run-time
requires 'YAML';
requires 'Dancer' => 1.3110;
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


install_script glob('bin/*');

install_share 'share';

auto_install

tests_recursive;

WriteAll;

