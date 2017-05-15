DOCKER_NAME=
DOCKER_IMAGE=
STOP_HTTP=1

if test -d /Users/rk/Desktop/workspace; then
	DOCKER_MOUNT="-v /Users/rk/Desktop/workspace:/docker/workspace"
fi

if test -f /etc/passwd; then
  SET_UID=`id -u`
  SET_GID=`id -g`
  DOCKER_UID_GID="-e SET_UID=$SET_UID -e SET_GID=$SET_GID"
fi

DOCKER_RUN="-it -p 80:80 -p 443:443 $DOCKER_MOUNT $DOCKER_UID_GID"
