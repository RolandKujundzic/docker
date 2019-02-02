#!/bin/sh
#
# @see https://github.com/sgerrand/alpine-pkg-glibc
#

cd /root

apk add --no-cache ca-certificates

GLIBC_VERSION=2.28-r0

wget -q -O "/etc/apk/keys/sgerrand.rsa.pub" "https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub"
wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-$GLIBC_VERSION.apk"
LD_USE_LOAD_BIAS=0 apk add --no-cache "glibc-$GLIBC_VERSION.apk"
wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-bin-$GLIBC_VERSION.apk"
LD_USE_LOAD_BIAS=0 apk add --no-cache "glibc-bin-$GLIBC_VERSION.apk"
wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-i18n-$GLIBC_VERSION.apk"
LD_USE_LOAD_BIAS=0 apk add --no-cache "glibc-i18n-$GLIBC_VERSION.apk"

# Iterate through all locale and install, e.g. /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8
# cat locale.md | xargs -i /usr/glibc-compat/bin/localedef -i {} -f UTF-8 {}.UTF-8

echo "create locale de_DE"
/usr/glibc-compat/bin/localedef -i de_DE -f UTF-8 de_DE.UTF-8

echo "check locale: /usr/glibc-compat/bin/locale [-a]"

