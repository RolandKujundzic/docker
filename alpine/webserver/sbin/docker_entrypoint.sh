#!/bin/ash

#------------------------------------------------------------------------------
function _log {
	echo "$1"

	if ! test -z "$DOCKER_LOGDIR" && test -f "$DOCKER_LOGDIR/docker.log"; then
		echo "$1" >> "$DOCKER_LOGDIR/docker.log"
  fi
}


#------------------------------------------------------------------------------
function _docker_log {

	if ! test -d /webhome/app/data; then
		return
	fi

	DOCKER_LOGDIR="/webhome/app/data/docker"

  if ! test -d "$DOCKER_LOGDIR"; then
    mkdir -p "$DOCKER_LOGDIR"
  fi

  if ! test -f "$DOCKER_LOGDIR/docker.log"; then
    local TS=`date +'%Y-%m-%d %H:%M:%S'`
    echo "$TS" > "$DOCKER_LOGDIR/docker.log"
  fi

  if ! test -L "$DOCKER_LOGDIR/apache_error.log"; then
    ln -sf "$DOCKER_LOGDIR/apache_error.log" "/var/log/apache2/error.log"
  fi

  if ! test -L /webhome/app/data/docker/apache_access.log; then
    ln -sf "$DOCKER_LOGDIR/apache_access.log" "/var/log/apache2/access.log"
  fi
}


#------------------------------------------------------------------------------
# M A I N
#------------------------------------------------------------------------------

_docker_log

if ! test -z "$SET_UID" && ! test "$SET_UID" = "1000"; then
	_log "usermod -u $SET_UID rk"
	usermod -u $SET_UID rk
fi

if ! test -z "$SET_GID" && ! test "$SET_GID" = "1000"; then
	_log "groupmod -g $SET_GID rk"
	groupmod -g $SET_GID rk
fi

if ! test -f /etc/ssh/ssh_host_rsa_key; then
	_log "ssh-keygen -A"
	ssh-keygen -A
fi

_log "start sshd: /usr/sbin/sshd"
/usr/sbin/sshd 

if ! test -d /var/lib/mysql/mysql; then
	_log "initialize mysql: mysql_install_db --user=mysql"
	mysql_install_db --user=mysql > /dev/null

	_log "prepare: /run/mysqld"
	if ! test -d "/run/mysqld"; then
		mkdir -p /run/mysqld
	fi

	chown -R mysql:mysql /run/mysqld

	if test -z "$MYSQL_ROOT_PASS"; then
		MYSQL_ROOT_PASS=`pwgen 16 1`
		_log "[i] MySQL root Password: $MYSQL_ROOT_PASS"
	fi

	CREATE_SQL_ADMIN=
	if ! test -z "$SQL_PASS"; then
		_log "[i] Create MySQL Administrator sql:$SQL_PASS"
		CREATE_SQL_ADMIN="GRANT ALL PRIVILEGES ON *.* TO 'sql'@'localhost' IDENTIFIED BY '$SQL_PASS' WITH GRANT OPTION;"
	fi

	CREATE_DB=
	if ! test -z "$DB_NAME" && ! test -z "$DB_PASS"; then
		_log "[i] Create MySQL Database $DB_NAME and account $DB_NAME:$DB_PASS"
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

	_log "/usr/bin/mysqld --bootstrap --verbose=1 --skip-name-resolve < $TFILE"
	/usr/bin/mysqld --bootstrap --verbose=1 --skip-name-resolve < $TFILE
fi

_log "start mysqld: /usr/bin/mysqld_safe"
/usr/bin/mysqld_safe

_log "start apache2: /usr/sbin/httpd -k start"
/usr/sbin/httpd -k start

_log "exec: $@"
exec "$@"

