#
# Webdevelopment environment: Ubuntu 16.04 (german) with apache2 + modphp + php7 + mariadb
#

FROM ubuntu:xenial
MAINTAINER Roland Kujundzic <roland@kujundzic.de>

ENV TERM xterm-256color

# be noninteractive only during build
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update && apt-get -y upgrade

# install basic tools
RUN apt-get -y install dialog curl vim nano sudo wget language-pack-de openssh-client rsync ssl-cert realpath patch zip unzip git \
	iputils-ping apache2-utils  

# install php7 + apache2 + cli + mariadb + sqlite
RUN apt-get -y install apache2 libapache2-mod-php7.0 mariadb-client mariadb-server php7.0-mysql php7.0-imap sqlite3 php7.0-sqlite3 \
	mongodb php-mongodb php7.0-mbstring php7.0-mcrypt php7.0-zip php7.0-xsl php7.0-tidy php7.0-json php7.0-gd php7.0-curl php7.0-soap \
	php-xdebug imagemagick telnet

# compile apcu
RUN apt-get -y install php7.0-dev php-pear
RUN yes '' | pecl install apcu && echo "extension=apcu.so" > /etc/php/7.0/mods-available/apcu.ini && phpenmod -v 7.0 -s ALL apcu

# configure shell, timezone, language
RUN rm -f /bin/sh; cd /bin; ln -s bash sh; \
	ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime; \ 
	echo "Europe/Berlin" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata; \
	echo "de_DE.UTF-8 UTF-8" >> /var/lib/locales/supported.d/de; dpkg-reconfigure -f noninteractive locales

ENV LANG=de_DE.UTF-8 LANGUAGE=de_DE:de LC_ALL=de_DE.UTF-8  

# configure apache + php
RUN a2enmod rewrite headers && \
	echo "xdebug.show_error_trace = 1" >> /etc/php/7.0/mods-available/xdebug.ini

# use "docker run -u rk" to run as user rk
RUN useradd -U -u 1000 -G sudo -m -s /bin/bash rk

# config files
COPY volume /

ENTRYPOINT ["/sbin/entrypoint.sh"]

# start apache2 + mysql
WORKDIR /docker/workspace
VOLUME [ "/docker" ]
EXPOSE 80/tcp 443/tcp

CMD ["/bin/bash"]
