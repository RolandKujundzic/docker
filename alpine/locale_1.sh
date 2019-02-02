#!/bin/sh
#
# @see https://github.com/rilian-la-te/musl-locales.git 
#

# install compile environment:
apk update && apk add --no-cache cmake make musl-dev gcc gettext-dev libintl

# install custom locale version
cd /root
git clone https://github.com/rilian-la-te/musl-locales.git
cd musl-locales 
cmake . && make && make install

# check locale 
MUSL_LOCPATH=/usr/local/share/i18n/locales/musl /usr/local/bin/locale -a

# backup locale - ldd /usr/local/bin/locale
cd /
tar -czvf locale_1.tgz \
	/usr/local/etc/profile.d/00locale.sh \
	/usr/local/bin/locale /usr/local/share/locale/* \
	/usr/local/share/i18n/locales/musl/*.UTF-8 \
	/lib/ld-musl-x86_64.so.1 /usr/lib/libintl.so.8 /usr/lib/libintl.so.8.1.5

echo "scp locale_1.tgz rk@192.168.0.57:/path/to/rkdocker/alpine/"
