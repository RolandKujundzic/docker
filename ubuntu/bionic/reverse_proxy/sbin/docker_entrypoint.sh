#!/bin/bash

if test -f /etc/init.d/apache2; then
	service apache2 start
fi

exec "$@"
