#!/usr/bin/perl -wl

use Net::DNS;
use Modern::Perl;
use Time::HiRes qw(tv_interval gettimeofday);

my @domains = ('perl.org','cpan.org','perlmonks.org','perlfoundation.org','perlweekly.com','perlbuzz.com','perlsphere.net', 'brukere.startsiden.no', 'www.abcnyheter.no');
my @servers = ('77.40.177.113', '195.159.0.100', '195.159.0.200');

my $res=Net::DNS::Resolver->new;
while(1) {
    foreach my $server (@servers) {
        $res->nameservers($server);
        foreach my $domain(@domains){
            my $t0 = [gettimeofday];
            my $answer = $res->search("$domain");
            my $int = tv_interval($t0);

            print join " ", (
                scalar localtime,
                ($int > 1 ? " SLOW! " : ""),
                $int,
                $answer->answerfrom,
                $answer->answersize,
                "$domain:",
                map { $_->address } grep { $_->type eq "A" } $answer->answer
            );
        }
        sleep 0.01;
   }
}
