FROM debian:wheezy

# Add startsiden repositories
RUN echo "deb http://wheezyapt.startsiden.no/ wheezy main contrib non-free" >> /etc/apt/sources.list
RUN echo "deb http://wheezyaptbuilder-dev.startsiden.no/ wheezy main contrib non-free" >> /etc/apt/sources.list

# Install dependencies
ADD . /setup
ADD docker/files/installdeps /setup/bin/installdeps
RUN apt-get -y update && apt-get -y install sudo && cd /setup && bin/installdeps

EXPOSE 3000

WORKDIR /pipr-ws
CMD ["bin/pipr-ws"]