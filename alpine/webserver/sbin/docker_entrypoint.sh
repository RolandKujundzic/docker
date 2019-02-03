#!/bin/ash

if ! test -z "$SET_UID" && ! test "$SET_UID" = "1000"; then
	usermod -u $SET_UID rk
fi

if ! test -z "$SET_GID" && ! test "$SET_GID" = "1000"; then
	groupmod -g $SET_GID rk
fi


if ! test -f /etc/ssh/ssh_host_rsa_key; then
	ssh-keygen -A
fi

# start sshd
/usr/sbin/sshd 

if ! test -d /var/lib/mysql/mysql; then
	mysql_install_db --user=mysql > /dev/null

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
		echo "[i] Create MySQL Administrator sql:$SQL_PASS"
		CREATE_SQL_ADMIN="GRANT ALL PRIVILEGES ON *.* TO 'sql'@'localhost' IDENTIFIED BY '$SQL_PASS' WITH GRANT OPTION;"
	fi

	CREATE_DB=
	if ! test -z "$DB_NAME" && ! test -z "$DB_PASS"; then
		echo "[i] Create MySQL Database $DB_NAME and account $DB_NAME:$DB_PASS"
		CREATE_DB="CREATE DATABASE `$DB_NAME`; GRANT ALL PRIVILEGES ON `$DB_NAME`.* TO '$DB_NAME'@'localhost' IDENTIFIED BY '$DB_PASS';"
	fi

	TFILE=`mktemp`
	cat << EOF > $TFILE
USE mysql;
UPDATE user SET password=PASSWORD('$MYSQL_ROOT_PASS') WHERE user='root' AND host='localhost';
FLUSH PRIVILEGES;
DROP DATABASE IF EXISTS test;
$CREATE_SQL_ADMIN
FLUSH PRIVILEGES;
$CREATE_DB
EOF

	/usr/bin/mysqld --bootstrap --verbose=1 --skip-name-resolve < $TFILE
fi

# start mysqld
/usr/bin/mysqld_safe

# check processes ... kill container if one is down
/sbin/docker_check.sh

exec "$@"

