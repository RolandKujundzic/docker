#!/bin/bash

if test -d /webhome/rk; then
	if ! test -z "$SET_UID"; then
		usermod -u $SET_UID rk
	fi

	if ! test -z "$SET_GID"; then
		groupmod -g $SET_GID rk
	fi
fi

if test -f /etc/init.d/mysql; then
	if ! test -d /var/lib/mysql/mysql; then
		CREATE_MYSQL_ACCOUNT=y
		mysql_install_db
	fi

	service mysql start

	if ! test -z "$SQL_PASS"; then
		# create mysql administrator account sql:$SQL_PASS
		echo "GRANT ALL PRIVILEGES ON *.* TO 'sql'@'localhost' IDENTIFIED BY '$SQL_PASS' WITH GRANT OPTION" | mysql -u root
	fi

	if ! test -z "$DB_NAME" && ! test -z "$DB_PASS"; then
		mysql-create "$DB_NAME" "$DB_PASS"
	fi
fi

if test -f /etc/init.d/apache2; then
	service apache2 start
fi

if test -f /etc/init.d/ssh; then
	service ssh start
fi

if test -f /webhome/docker.sh; then
	# custom startup
	/webhome/docker.sh
fi

exec "$@"
