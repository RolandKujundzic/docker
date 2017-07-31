#!/bin/bash
MERGE2RUN="syntax abort is_running os_type stop_http docker_rm docker_stop main"


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
# Abort with error message.
#
# @param abort message
#------------------------------------------------------------------------------
function _abort {
	echo -e "\nABORT: $1\n\n" 1>&2
	exit 1
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
# @require os_type
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
# Return linux, macos, cygwin.
#
# @print string
#------------------------------------------------------------------------------
function _os_type {
	if [ "$(uname)" = "Darwin" ]; then
		echo "macos"        
	elif [ "$OSTYPE" = "linux-gnu" ]; then
		echo "linux"
	elif [ $(expr substr $(uname -s) 1 5) = "Linux" ]; then
		echo "linux"
	elif [ $(expr substr $(uname -s) 1 5) = "MINGW" ]; then
		echo "cygwin"
	fi
}

#------------------------------------------------------------------------------
# Stop webserver (apache2, nginx) on port 80 if running.
# Ignore docker webservice on port 80.
#
# @require is_running os_type
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
# Remove stopped docker container (if found).
#
# @param name
# @require docker_stop
#------------------------------------------------------------------------------
function _docker_rm {
	_docker_stop "$1"

	local HAS_CONTAINER=`docker ps -a | grep "$1"`

	if ! test -z "$HAS_CONTAINER"; then
		echo "docker rm $1"
		docker rm "$1"
	fi
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
# M A I N
#------------------------------------------------------------------------------

APP=$0

if ! test -d "$1"; then
	_syntax "[container/image] [build|start|stop]\n\nDOCKER_NAME=MyContainer ./run.sh ubuntu/xenial start" 
fi

. $1/config.sh

if test -z "$DOCKER_IMAGE"; then
	DOCKER_IMAGE=`echo "$1" | sed -e 's#[/ ]#_#g'`
fi

if test -z "$DOCKER_NAME"; then
	DOCKER_NAME="rk_$DOCKER_IMAGE"
fi


echo

case $2 in
build)
	echo -e "docker build -t rk:$DOCKER_IMAGE $1\nYou might need to type in root password\n"
	docker build -t rk:$DOCKER_IMAGE $1
	;;
start)
	if ! test -z "$STOP_HTTP"; then
		_stop_http
	fi

	_docker_rm $DOCKER_NAME

	echo "docker run $DOCKER_RUN --name $DOCKER_NAME rk:$DOCKER_IMAGE"
	docker run $DOCKER_RUN --name $DOCKER_NAME rk:$DOCKER_IMAGE
	;;
stop)
	_docker_stop $DOCKER_NAME
	;;
*)
	_syntax "container/image [build|start|stop]"
esac

echo

