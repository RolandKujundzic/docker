#!/bin/bash

if ! test -z "$SET_UID"; then
	usermod -u $SET_UID rk
fi

if ! test -z "$SET_GID"; then
	groupmod -g $SET_GID rk
fi

if ! test -d /var/lib/mysql/mysql; then
	mysql_install_db --user=mysql > /dev/null
  chown -R mysql.mysql /var/lib/mysql

	if ! test -d "/run/mysqld"; then
		mkdir -p /run/mysqld
	fi

	chown -R mysql:mysql /run/mysqld

	if test -z "$MYSQL_ROOT_PASS"; then
		MYSQL_ROOT_PASS=`pwgen 16 1`
		echo "[i] MySQL root Password: $MYSQL_ROOT_PASS"
	fi

	CREATE_SQL_ADMIN=
	if ! test -z "$SQL_PASS"; then
		# create mysql administrator account sql:$SQL_PASS
		CREATE_SQL_ADMIN="echo \"GRANT ALL PRIVILEGES ON *.* TO 'sql'@'localhost' IDENTIFIED BY '$SQL_PASS' WITH GRANT OPTION;\""
	fi

	CREATE_DB=
	if ! test -z "$DB_NAME" && ! test -z "$DB_PASS"; then
		CREATE_DB="CREATE DATABASE `$DB_NAME`; GRANT ALL PRIVILEGES ON `$DB_NAME`.* TO '$DB_NAME'@'localhost' IDENTIFIED BY '$DB_PASS';"
	fi

	TFILE=`mktemp`
	cat << EOF > $TFILE
USE mysql;
UPDATE user SET password=PASSWORD('$MYSQL_ROOT_PASS') WHERE user='root' AND host='localhost';
DROP DATABASE test;
$CREATE_SQL_ADMIN
$CREATE_DB
EOF

	/usr/bin/mysqld --bootstrap --verbose=1 --skip-name-resolve < $TFILE
else
	/usr/bin/mysqld --bootstrap --verbose=0 --skip-name-resolve
fi

ssh-keygen -A
/usr/sbin/sshd 

exec "$@"
