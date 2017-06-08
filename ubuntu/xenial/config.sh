DOCKER_NAME=
DOCKER_IMAGE=
STOP_HTTP=1

if test -d /Users/$USER/Desktop/workspace; then
	DOCKER_MOUNT="-v /Users/$USER/Desktop/workspace:/docker/workspace"
elif test -d /home/$USER/Desktop/workspace; then
	DOCKER_MOUNT="-v /home/$USER/Desktop/workspace:/docker/workspace"
fi

if test -f /etc/passwd; then
  SET_UID=`id -u`
  SET_GID=`id -g`
  DOCKER_UID_GID="-e SET_UID=$SET_UID -e SET_GID=$SET_GID"
fi

DOCKER_RUN="-it -p 80:80 -p 443:443 -e SQL_PASS='admin' $DOCKER_MOUNT $DOCKER_UID_GID"
