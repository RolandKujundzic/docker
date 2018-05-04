#!/bin/bash


#------------------------------------------------------------------------------
# Export DOCKER_RUN. Create sql:admin mysql account. Set UID and GID 
# if /etc/passwd exists. Mount DOCROOT or workspace.
#------------------------------------------------------------------------------
function _export_docker_run {
	if ! test -z "$DOCROOT" && test -d $DOCROOT; then
  	DOCKER_MOUNT="--mount source=$DOCROOT,target=$DOCROOT,type=bind"
	elif test -d /Users/$USER/Desktop/workspace; then
  	DOCKER_MOUNT="--mount source=/Users/$USER/Desktop/workspace,target=/docker/workspace,type=bind"
	elif test -d /home/$USER/Desktop/workspace; then
  	DOCKER_MOUNT="--mount source=/home/$USER/Desktop/workspace,target=/docker/workspace,type=bind"
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
	_syntax "[linux/version/config.sh] [build|start|stop]\n\nDOCKER_NAME=MyContainer ./run.sh ubuntu/xenial/config.sh start" 
fi

LINUX_VERSION=`dirname $1`

. $1

if test "$2" = "start"; then
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

