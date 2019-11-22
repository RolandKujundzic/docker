#!/bin/bash
MERGE2RUN="abort confirm docker_stop is_running os_type stop_http syntax  main"


test -z "$RKSCRIPT_DIR" && RKSCRIPT_DIR=".rkscript"

#------------------------------------------------------------------------------
# Abort with error message. Use NO_ABORT=1 for just warning output.
#
# @exit
# @global APP, NO_ABORT
# @param abort message
#------------------------------------------------------------------------------
function _abort {
	if test "$NO_ABORT" = 1; then
		echo "WARNING: $1"
		return
	fi

	echo -e "\nABORT: $1\n\n" 1>&2

	local other_pid=

	if ! test -z "$APP_PID"; then
		# make shure APP_PID dies
		for a in $APP_PID; do
			other_pid=`ps aux | grep -E "^.+\\s+$a\\s+" | awk '{print $2}'`
			test -z "$other_pid" || kill $other_pid 2> /dev/null 1>&2
		done
	fi

	if ! test -z "$APP"; then
		# make shure APP dies
		other_pid=`ps aux | grep "$APP" | awk '{print $2}'`
		test -z "$other_pid" || kill $other_pid 2> /dev/null 1>&2
	fi

	exit 1
}


#------------------------------------------------------------------------------
# Show "message  Press y or n  " and wait for key press. 
# Set CONFIRM=y if y key was pressed. Otherwise set CONFIRM=n if any other 
# key was pressed or 10 sec expired. Use --q1=y and --q2=n call parameter to confirm
# question 1 and reject question 2. Set CONFIRM_COUNT= before _confirm if necessary.
#
# @param string message
# @param 2^N flag 1=switch y and n (y = default, wait 3 sec) | 2=auto-confirm (y)
# @export CONFIRM CONFIRM_TEXT
#------------------------------------------------------------------------------
function _confirm {
	CONFIRM=

	if test -z "$CONFIRM_COUNT"; then
		CONFIRM_COUNT=1
	else
		CONFIRM_COUNT=$((CONFIRM_COUNT + 1))
	fi

	local FLAG=$(($2 + 0))

	if test $((FLAG & 2)) = 2; then
		if test $((FLAG & 1)) = 1; then
			CONFIRM=n
		else
			CONFIRM=y
		fi

		return
	fi

	while read -d $'\0' 
	do
		local CCKEY="--q$CONFIRM_COUNT"
		if test "$REPLY" = "$CCKEY=y"; then
			echo "found $CCKEY=y, accept: $1" 
			CONFIRM=y
		elif test "$REPLY" = "$CCKEY=n"; then
			echo "found $CCKEY=n, reject: $1" 
			CONFIRM=n
		fi
	done < /proc/$$/cmdline

	if ! test -z "$CONFIRM"; then
		# found -y or -n parameter
		CONFIRM_TEXT="$CONFIRM"
		return
	fi

	local DEFAULT=

	if test $((FLAG & 1)) -ne 1; then
		DEFAULT=n
		echo -n "$1  y [n]  "
		read -n1 -t 10 CONFIRM
		echo
	else
		DEFAULT=y
		echo -n "$1  [y] n  "
		read -n1 -t 3 CONFIRM
		echo
	fi

	if test -z "$CONFIRM"; then
		CONFIRM=$DEFAULT
	fi

	CONFIRM_TEXT="$CONFIRM"

	if test "$CONFIRM" != "y"; then
		CONFIRM=n
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
	_os_type linux

	if test -z "$1"; then
		_abort "no process name"
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
# @print string (abort if set and os_type != $1)
#------------------------------------------------------------------------------
function _os_type {
	local os=

	if [ "$(uname)" = "Darwin" ]; then
		os="macos"        
	elif [ "$OSTYPE" = "linux-gnu" ]; then
		os="linux"
	elif [ $(expr substr $(uname -s) 1 5) = "Linux" ]; then
		os="linux"
	elif [ $(expr substr $(uname -s) 1 5) = "MINGW" ]; then
		os="cygwin"
	fi

	if ! test -z "$1" && test "$1" != "$os"; then
		_abort "$os required (this is $os)"
	fi

	echo $os
}

#------------------------------------------------------------------------------
# Stop webserver (apache2, nginx) on port 80 if running.
# Ignore docker webservice on port 80.
#
# @require _is_running _os_type
# @os linux
#------------------------------------------------------------------------------
function _stop_http {
  _os_type linux

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
# @global APP, APP_DESC, $APP_PREFIX
# @param message
#------------------------------------------------------------------------------
function _syntax {
	if ! test -z "$APP_PREFIX"; then
		echo -e "\nSYNTAX: $APP_PREFIX $APP $1\n" 1>&2
	else
		echo -e "\nSYNTAX: $APP $1\n" 1>&2
	fi

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
# or /path/to/Desktop/workspace to /docker/workspace. Append DOCKER_PARAMETER
# to DOCKER_RUN.
#------------------------------------------------------------------------------
function _export_docker_run {
	if ! test -z "$DOCROOT_SOURCE" && test -d "$DOCROOT_SOURCE"; then
		test -z "$DOCROOT_TARGET" && DOCROOT_TARGET="/webhome/$DOCKER_NAME"
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

	DOCKER_RUN="-d -e SQL_PASS=admin $DOCKER_MOUNT $DOCKER_UID_GID $DOCKER_PARAMETER"
}


#------------------------------------------------------------------------------
# M A I N
#------------------------------------------------------------------------------

APP=$0
APP_DESC="Control docker. Autodetect name if DOCKER_NAME=MyContainer ./run.sh ... is not used."

export APP_PID="$APP_PID $$"

test -s "$1" || _syntax "path/to/config.sh build|start|stop|show|run"

CONFIG_DIR=`dirname "$1"`

. $1 || _abort "load configuration $1 failed"

if test "$2" = "start" || test "$2" = "run" || test "$2" = "show"; then
	_export_docker_run
fi

if test -z "$DOCKER_IMAGE"; then
	_abort "export DOCKER_IMAGE in $1"
fi

if test "$2" = "build"; then
	if test -z "$DOCKER_DF" && test -s "$CONFIG_DIR/Dockerfile"; then
		DOCKER_DF=Dockerfile
	else
		_abort "export DOCKER_DF=Dockerfile in $1"
	fi
elif test -z "$DOCKER_NAME"; then
	DOCKER_NAME=`basename "$1" | sed -E 's/\.sh$//'`
	_confirm "Use DOCKER_NAME=$DOCKER_NAME" 1
	test "$CONFIRM" = "y" || _abort "export DOCKER_NAME in shell or $1"
fi

echo

case $2 in
build)
	echo -e "docker build -t $DOCKER_IMAGE $1\nYou might need to type in root password\n"
	docker build -t $DOCKER_IMAGE -f "$CONFIG_DIR/$DOCKER_DF" "$CONFIG_DIR"
	;;
run)
	HAS_DOCKER=`docker ps -a | grep "$DOCKER_NAME\$"`
	if test -z "$HAS_DOCKER"; then
		echo "docker run $DOCKER_RUN --name $DOCKER_NAME $DOCKER_IMAGE"
	else
		echo "docker start $DOCKER_NAME"
	fi
	;;
show)
	echo "docker run $DOCKER_RUN --name $DOCKER_NAME $DOCKER_IMAGE"
	;;
start)
	if ! test -z "$STOP_HTTP"; then
		_stop_http
	fi

	HAS_DOCKER=`docker ps -a | grep "$DOCKER_NAME\$"`
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
	_syntax "path/to/config.sh build|start|stop|show|run"
esac

echo

