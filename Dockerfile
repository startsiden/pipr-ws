FROM debian:wheezy

# Add startsiden repositories
RUN echo "deb http://wheezyapt.startsiden.no/ wheezy main contrib non-free" >> /etc/apt/sources.list
RUN echo "deb http://wheezyaptbuilder-dev.startsiden.no/ wheezy main contrib non-free" >> /etc/apt/sources.list
RUN apt-get -y update && apt-get -y install sudo cpan-libmodule-install-debian-perl libgdbm3 libmodule-install-perl apt-file

COPY docker/files/installdeps /usr/local/bin
WORKDIR /pipr-ws

ADD Makefile.PL .
RUN mkdir -p lib/Pipr
ADD lib/Pipr/WS.pm lib/Pipr/

RUN installdeps

# Add code base
ADD . .

EXPOSE 3000
EXPOSE 3443

CMD ["bin/pipr-ws"]
