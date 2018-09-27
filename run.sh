#!/bin/bash
MERGE2RUN="abort docker_stop is_running stop_http syntax main"


#------------------------------------------------------------------------------
# Abort with error message.
#
# @param abort message
#------------------------------------------------------------------------------
function _abort {
	echo -e "\nABORT: $1\n\n" 1>&2
	exit 1
}


#------------------------------------------------------------------------------
# Stop running docker container (if found).
#
# @param name
#------------------------------------------------------------------------------
function _docker_stop {
	local HAS_CONTAINER=`docker ps | grep "$1"`

	if ! test -z "$HAS_CONTAINER"; then
		echo "docker stop $1"
		docker stop "$1"
	fi
}


#------------------------------------------------------------------------------
# Abort with error message. Process Expression is either CUSTOM with 
# regular expression as second parameter (first character must be in brackets)
# or PORT with port number as second parameter or expression name from list:
#
# NGINX, APACHE2, DOCKER_PORT_80, DOCKER_PORT_443 
#
# Example:
#
# if test "$(_is_running APACHE2)" = "APACHE2_running"; then
# if test "$(_is_running PORT 80)" != "PORT_running"; then
# if test "$(_is_running CUSTOM [a]pache2)" = "CUSTOM_running"; then
#
# @param Process Expression Name 
# @param Regular Expression if first parameter is CUSTOM e.g. [a]pache2
# @require _abort _os_type
# @os linux
# @return "$1_running"
#------------------------------------------------------------------------------
function _is_running {

	if test -z "$1"; then
		_abort "no process name"
	fi

	local OS_TYPE=$(_os_type)
	if test "$OS_TYPE" != "linux"; then
		return
	fi		

	# use [a] = a to ignore "grep process"
	local APACHE2='[a]pache2.*k start'
	local DOCKER_PORT_80='[d]ocker-proxy.* -host-port 80'
	local DOCKER_PORT_443='[d]ocker-proxy.* -host-port 443'
	local NGINX='[n]ginx.*master process'

	local IS_RUNNING=

	if ! test -z "$2"; then
		if test "$1" = "CUSTOM"; then
			IS_RUNNING=$(ps aux | grep -E "$2")
		elif test "$1" = "PORT"; then
			IS_RUNNING=$(netstat -tulpn | grep ":$2")
		fi
	elif test -z "${!1}"; then
		_abort "invalid grep expression name $1 (use NGINX, APACHE2, DOCKER_PORT80, ... or CUSTOM '[n]ame')"
	else
		IS_RUNNING=$(ps aux | grep -E "${!1}")
	fi

	if ! test -z "$IS_RUNNING"; then
		echo "$1_running"
	fi
}


#------------------------------------------------------------------------------
# Stop webserver (apache2, nginx) on port 80 if running.
# Ignore docker webservice on port 80.
#
# @require _is_running _os_type
# @os linux
#------------------------------------------------------------------------------
function _stop_http {

  local OS_TYPE=$(_os_type)
  if test "$OS_TYPE" != "linux"; then
    return
  fi

  if test "$(_is_running PORT 80)" != "PORT_running"; then
    echo "no service on port 80"
    return
  fi 

  if test "$(_is_running DOCKER_PORT_80)" = "DOCKER_PORT_80_running"; then
    echo "ignore docker service on port 80"
    return
  fi

  if test "$(_is_running NGINX)" = "NGINX_running"; then
    echo "stop nginx"
    sudo service nginx stop
    return
  fi

  if test "$(_is_running APACHE2)" = "APACHE2_running"; then
    echo "stop apache2"
    sudo service apache2 stop
    return
  fi
}


#------------------------------------------------------------------------------
# Abort with SYNTAX: message.
# Usually APP=$0
#
# @global APP, APP_DESC
# @param message
#------------------------------------------------------------------------------
function _syntax {
	echo -e "\nSYNTAX: $APP $1\n" 1>&2

	if ! test -z "$APP_DESC"; then
		echo -e "$APP_DESC\n\n" 1>&2
	else
		echo 1>&2
	fi

	exit 1
}



#------------------------------------------------------------------------------
# Export DOCKER_RUN. Create sql:admin mysql account. Set UID and GID 
# if /etc/passwd exists. Mount DOCROOT_SOURCE to /webhome/DOCKER_NAME (=DOCROOT_TARGET)
# or /path/to/Desktop/workspace to /docker/workspace.
#------------------------------------------------------------------------------
function _export_docker_run {
	if ! test -z "$DOCROOT_SOURCE" && test -d $DOCROOT_SOURCE; then
		if test -z "$DOCROOT_TARGET"; then
			DOCROOT_TARGET="/webhome/$DOCKER_NAME"
		fi

  	DOCKER_MOUNT="--mount type=bind,source=$DOCROOT_SOURCE,target=$DOCROOT_TARGET"
	elif test -d /Users/$USER/Desktop/workspace; then
  	DOCKER_MOUNT="--mount type=bind,source=/Users/$USER/Desktop/workspace,target=/docker/workspace"
	elif test -d /home/$USER/Desktop/workspace; then
  	DOCKER_MOUNT="--mount type=bind,source=/home/$USER/Desktop/workspace,target=/docker/workspace"
	fi

	if test -f /etc/passwd; then
  	SET_UID=`id -u`
  	SET_GID=`id -g`

  	if test "$SET_GID" -ge 1000 && test "$SET_UID" -ge 1000
  	then
    	DOCKER_UID_GID="-e SET_UID=$SET_UID -e SET_GID=$SET_GID"
  	fi
	fi

	DOCKER_RUN="-d -e SQL_PASS=admin $DOCKER_MOUNT $DOCKER_UID_GID"
}


#------------------------------------------------------------------------------
# M A I N
#------------------------------------------------------------------------------

APP=$0

if ! test -f "$1"; then
	_syntax "[linux/version/config.sh] [build|start|stop|run]\n\nDOCKER_NAME=MyContainer ./run.sh ubuntu/xenial/config.sh start" 
fi

LINUX_VERSION=`dirname $1`

. $1

if test "$2" = "start" || test "$2" = "run"; then
	_export_docker_run
fi

if test -z "$DOCKER_IMAGE"; then
	_abort "export DOCKER_IMAGE in $1"
fi

if test -z "$DOCKER_NAME" && test "$2" != "build"; then
	_abort "export DOCKER_NAME in shell or $1"
fi

if test -z "$DOCKER_DF" && test "$2" = "build"; then
	if test -f $LINUX_VERSION/Dockerfile; then
		DOCKER_DF=Dockerfile
	else
		_abort "export DOCKER_DF=Dockerfile in $1"
	fi
fi

echo

case $2 in
build)
	echo -e "docker build -t $DOCKER_IMAGE $1\nYou might need to type in root password\n"
	docker build -t $DOCKER_IMAGE -f $LINUX_VERSION/$DOCKER_DF $LINUX_VERSION
	;;
run)
	HAS_DOCKER=`docker ps -a | grep $DOCKER_NAME`
	if test -z "$HAS_DOCKER"; then
		echo "docker run $DOCKER_RUN --name $DOCKER_NAME $DOCKER_IMAGE"
	else
		echo "docker start $DOCKER_NAME"
	fi
	;;
start)
	if ! test -z "$STOP_HTTP"; then
		_stop_http
	fi

	HAS_DOCKER=`docker ps -a | grep $DOCKER_NAME`
	if test -z "$HAS_DOCKER"; then
		echo "docker run $DOCKER_RUN --name $DOCKER_NAME $DOCKER_IMAGE"
		docker run $DOCKER_RUN --name $DOCKER_NAME $DOCKER_IMAGE
	else
		echo "docker start $DOCKER_NAME"
		docker start $DOCKER_NAME
	fi
	;;
stop)
	_docker_stop $DOCKER_NAME
	;;
*)
	_syntax "container/image [build|start|stop]"
esac

echo

