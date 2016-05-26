FROM debian:wheezy

# Add startsiden repositories
RUN echo "deb http://wheezyapt.startsiden.no/ wheezy main contrib non-free" >> /etc/apt/sources.list
RUN echo "deb http://wheezyaptbuilder-dev.startsiden.no/ wheezy main contrib non-free" >> /etc/apt/sources.list

# Running non-interactively
# See https://github.com/phusion/baseimage-docker/issues/58
RUN apt-get -y update
RUN DEBIAN_FRONTEND=noninteractive apt-get -q -y --allow-unauthenticated install apt-file
RUN apt-file update
RUN DEBIAN_FRONTEND=noninteractive apt-get -q -y --allow-unauthenticated install apt-utils
RUN DEBIAN_FRONTEND=noninteractive apt-get -q -y install --allow-unauthenticated cpan-libmodule-install-debian-perl libgdbm3 libmodule-install-perl
RUN DEBIAN_FRONTEND=noninteractive apt-get -q -y install --allow-unauthenticated libjs-jquery

COPY docker/files/installdeps /usr/local/bin
WORKDIR /pipr-ws

ADD Makefile.PL .
RUN mkdir -p lib/Pipr
ADD lib/Pipr/WS.pm lib/Pipr/

RUN DEBIAN_FRONTEND=noninteractive apt-get -q -y install sudo
RUN DEBIAN_FRONTEND=noninteractive installdeps

# Add code base
ADD . .

EXPOSE 3000

CMD ["bin/pipr-ws"]
