#!/bin/bash


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

