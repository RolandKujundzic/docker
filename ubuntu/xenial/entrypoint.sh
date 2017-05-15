#!/bin/bash

if ! test -z "$SET_UID"; then
	usermod -u $SET_UID rk
fi

if ! test -z "$SET_GID"; then
	groupmod -g $SET_GID rk
fi

if ! test -d /var/lib/mysql/mysql; then
	CREATE_MYSQL_ACCOUNT=y
	mysql_install_db
fi

service mysql start
service apache2 start

# create mysql administrator account sql:geheim
# echo "GRANT ALL PRIVILEGES ON *.* TO 'sql'@'localhost' IDENTIFIED BY 'geheim' WITH GRANT OPTION" | mysql -u root

if test -f /docker/workspace/run.sh; then
	# create workspace environment
	ln -s /docker/workspace /var/www/html 
	/docker/workspace/run.sh create_db
fi

exec "$@"

