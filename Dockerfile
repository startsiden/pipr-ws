FROM eu.gcr.io/divine-arcade-95810/perl:jessie
MAINTAINER tore.aursand@startsiden.no

RUN apt-get update && apt-get install -y --force-yes libcrypt-ssleay-perl libextutils-pkgconfig-perl libgd-perl && rm -rf /var/lib/apt/lists/*

COPY cpanfile .

ARG PINTO_STACK
ENV PINTO_STACK ${PINTO_STACK:-develop}

ENV PERL_CPANM_OPT --quiet --no-man-pages --skip-satisfied --mirror http://cpan.uib.no/ --mirror http://cpan.cpantesters.org --mirror http://cpan.metacpan.org --mirror http://admin:admin@pinto.startsiden.no/stacks/$PINTO_STACK

RUN cpanm --notest --installdeps .

ADD https://www.random.org/strings/?num=16&len=16&digits=on&upperalpha=on&loweralpha=on&unique=on&format=plain&rnd=new /tmp/CACHEBUST
RUN cpanm --notest --with-feature=own --installdeps .

ADD https://www.random.org/strings/?num=16&len=16&digits=on&upperalpha=on&loweralpha=on&unique=on&format=plain&rnd=new /tmp/CACHEBUST
RUN cpanm --with-feature=own --reinstall --installdeps .

COPY . .

EXPOSE 3000

CMD ["bin/pipr-ws"]
