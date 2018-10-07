#!/bin/bash

if ! test -z "$VPN_LOGIN" && ! test -z "$VPN_PASSWORD"; then
	echo -e "$VPN_LOGIN\n$VPN_PASSWORD" > /etc/openvpn/client/login.conf
	openvpn /etc/openvpn/client/Germany1.ovpn
fi

HAS_NET=`ping -c 1 heise.de 2> /dev/null | grep '64 bytes from'`
if test -z "$HAS_NET"; then
	echo -e "search google.com\nnameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
fi

cd /webhome

exec "$@"
