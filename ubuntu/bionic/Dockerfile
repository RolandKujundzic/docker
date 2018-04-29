#
# Webdevelopment environment: Ubuntu 18.04 (german) with apache2 + modphp + php7 + mariadb
#
# docker build -t rk:bionic .
# 
#

FROM ubuntu:bionic
MAINTAINER Roland Kujundzic <roland@kujundzic.de>

ENV TERM xterm-256color

# be noninteractive only during build
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update && apt-get -y upgrade

# install basic tools
RUN apt-get -y install apt-utils dialog curl vim nano sudo wget language-pack-de openssh-client rsync ssl-cert patch zip unzip git \
	iputils-ping apache2-utils  
	
# install php7.2 + apache2 + cli + mariadb + sqlite + sshd + pureftpd
RUN apt-get -y install apache2 libapache2-mod-php7.2 mariadb-client mariadb-server php7.2-mysql php7.2-imap sqlite3 php7.2-sqlite3 \
	mongodb php-mongodb php7.2-mbstring php7.2-zip php7.2-xsl php7.2-tidy php7.2-json php7.2-gd php7.2-curl php7.2-soap \
	php-xdebug imagemagick telnet openssh-server pure-ftpd-mysql
