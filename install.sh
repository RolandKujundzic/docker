#!/bin/bash


#------------------------------------------------------------------------------
function _install_docker {
	echo "install docker"
	sudo apt-get -y update
	sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo apt-get -y update
	sudo apt-get -y install docker-ce

	if test -d /home/$USER; then
		echo "allow $USER to run docker (login again)"
		sudo usermod -aG docker $USER
	fi
}


#------------------------------------------------------------------------------
function _download {
	local VERSION=`uname -s`-`uname -m`
	echo "curl -L $1-$VERSION > $2"
	sudo sh -c "curl -L $1-$VERSION > $2"
	sudo chmod +x $2
}


#------------------------------------------------------------------------------
# M A I N
#------------------------------------------------------------------------------

# update URL: https://github.com/docker/compose/releases/
DOCKER_COMPOSE_URL=https://github.com/docker/compose/releases/download/1.15.0/docker-compose
# update URL: https//github.com/docker/machine/releases/
DOCKER_MACHINE_URL=https://github.com/docker/machine/releases/download/v0.12.2/docker-machine
DOCKER_COMPOSE=/usr/local/bin/docker-compose
DOCKER_MACHINE=/usr/local/bin/docker-machine

# ask for user password - cache sudo authentication
sudo true
 
_install_docker
_download $DOCKER_COMPOSE_URL $DOCKER_COMPOSE
_download $DOCKER_MACHINE_URL $DOCKER_MACHINE
