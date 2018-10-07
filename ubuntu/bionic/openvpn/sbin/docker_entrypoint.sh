#!/bin/bash

if ! test -z "$VPN_LOGIN" && ! test -z "$VPN_PASSWORD"; then
	echo -e "$VPN_LOGIN\n$VPN_PASSWORD" > /etc/openvpn/client/login.conf
	openvpn /etc/openvpn/client/Germany1.ovpn
fi

exec "$@"
