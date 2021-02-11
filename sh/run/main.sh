#!/bin/bash
# shellcheck disable=SC2034,SC2086,SC2154,SC1090

#---
# Export DOCKER_RUN. Create sql:admin mysql account. Set UID and GID 
# if /etc/passwd exists. Mount DOCROOT_SOURCE to /webhome/DOCKER_NAME (=DOCROOT_TARGET)
# or /path/to/Desktop/workspace to /docker/workspace. Append DOCKER_PARAMETER
# to DOCKER_RUN.
#
# @global DOCROOT_SOURCE DOCKER_NAME DOCROOT_TARGET
# @export DOCKER_RUN
#---
function export_docker_run {
	local dmount set_uid sed_gid uid_gid
	if ! test -z "$DOCROOT_SOURCE" && test -d "$DOCROOT_SOURCE"; then
		test -z "$DOCROOT_TARGET" && DOCROOT_TARGET="/webhome/$DOCKER_NAME"
  	dmount="--mount type=bind,source=$DOCROOT_SOURCE,target=$DOCROOT_TARGET"
	elif test -d "/Users/$USER/Desktop/workspace"; then
  	dmount="--mount type=bind,source=/Users/$USER/Desktop/workspace,target=/docker/workspace"
	elif test -d "/home/$USER/Desktop/workspace"; then
  	dmount="--mount type=bind,source=/home/$USER/Desktop/workspace,target=/docker/workspace"
	fi

	if test -f /etc/passwd; then
  	set_uid=$(id -u)
  	set_gid=$(id -g)

  	if test "$set_gid" -ge 1000 && test "$set_uid" -ge 1000
  	then
    	uid_gid="-e set_uid=$set_uid -e set_gid=$set_gid"
  	fi
	fi

	DOCKER_RUN="-d -e SQL_PASS=admin $dmount $uid_gid $DOCKER_PARAMETER"
}


#---
# M A I N
#---

APP_DESC='Control docker. Autodetect name unless: DOCKER_NAME=MyContainer ./run.sh …'

_rks_app "$@"

test -f "${ARG[1]}" || _syntax "path/to/config.sh build|start|stop|show|run"
source "${ARG[1]}" || _abort "load configuration ${ARG[1]} failed"

CONFIG_DIR=$(dirname "${ARG[1]}")

_require_global DOCKER_IMAGE

[[ "${ARG[2]}" = "start" || "${ARG[2]}" = "run" || "${ARG[2]}" = "show" ]] && export_docker_run

if [[ "${ARG[2]}" = "build" && ! -f "$CONFIG_DIR/$DOCKER_DF" ]]; then
	if test -z "$DOCKER_DF" && test -s "$CONFIG_DIR/Dockerfile"; then
		DOCKER_DF=Dockerfile
	else
		_abort "export DOCKER_DF=Dockerfile in ${ARG[1]}"
	fi
elif test -z "$DOCKER_NAME"; then
	DOCKER_NAME=$(basename "${ARG[1]}" | sed -E 's/\.sh$//')
	_confirm "Use DOCKER_NAME=$DOCKER_NAME" 1
	test "$CONFIRM" = "y" || _abort "export DOCKER_NAME in shell or ${ARG[1]}"
fi

echo

case ${ARG[2]} in
build)
	echo -e "docker build -t $DOCKER_IMAGE\nYou might need to type in root password\n"
	docker build -t $DOCKER_IMAGE -f "$CONFIG_DIR/$DOCKER_DF" "$CONFIG_DIR"
	;;
run)
	HAS_DOCKER=$(docker ps -a | grep "$DOCKER_NAME\$")
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

	HAS_DOCKER=$(docker ps -a | grep "$DOCKER_NAME\$")
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

