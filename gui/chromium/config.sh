DOCKER_NAME=
DOCKER_IMAGE=
STOP_HTTP=
RUN_SH="xhost +local:"

DOCKER_RUN="--device /dev/snd -v /etc/localtime:/etc/localtime:ro -v /tmp/.X11-unix/X0:/tmp/.X11-unix/X0"
