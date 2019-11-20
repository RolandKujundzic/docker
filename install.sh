#!/bin/bash

if test -s /usr/local/lib/rkscript.sh; then
	. /usr/local/lib/rkscript.sh || exit 1
elif test -s rkscript.sh; then
	. rkscript.sh || exit 1
else
	wget -O rkscript.sh 'https://raw.githubusercontent.com/RolandKujundzic/rkscript/master/lib/rkscript.sh'

	if ! test -s rkscript.sh; then
		echo "checkout https://github.com/RolandKujundzic/rkscript/blob/master/lib/rkscript.sh as /usr/local/lib/rkscript.sh"
		exit 1
	fi

	. rkscript.sh || exit 1
fi


declare -A GITHUB_LATEST
declare -A GITHUB_IS_LATEST


#------------------------------------------------------------------------------
function _install_docker {
	_github_latest docker/docker-ce docker
	
	if test "${GITHUB_IS_LATEST[docker]}" = "1"; then
		echo "latest docker ${GITHUB_LATEST[docker]} is already installed"
		return
	fi

	echo "install docker [${GITHUB_IS_LATEST[docker]}] ${GITHUB_LATEST[docker]}"
	sudo apt-get -y update
	sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo apt-get -y update
	sudo apt-get -y install docker-ce

	if test -d /home/$SUDO_USER; then
		echo "allow $SUDO_USER to run docker (login again)"
		sudo usermod -aG docker $SUDO_USER
	fi
}


#------------------------------------------------------------------------------
function _download {
	_github_latest $1 $2
	local LATEST="${GITHUB_LATEST[$2]}"
	local VERSION=`uname -s`-`uname -m`

	if test "${GITHUB_IS_LATEST[$2]}" = "1"; then
		echo "latest $2 $LATEST is already installed"
		return
	fi

	if test -z "$LATEST" || test -z "$VERSION"; then
		_abort "download $2 failed"
	fi

	echo "LATEST=[$LATEST] IS_LATEST=[${GITHUB_IS_LATEST[$2]}]"
	local URL="https://github.com/$1/releases/download/$LATEST/$2-$VERSION"
	echo "curl -L '$URL' > '/usr/local/bin/$2'" 
	sudo sh -c "curl -L '$URL' > '/usr/local/bin/$2'" || _abort "download failed: $URL"

	local IS_ELF=`file /usr/local/bin/$2 | grep -E 'ELF 64-bit LSB executable'`
	if test -z "$IS_ELF"; then
		_abort "/usr/local/bin/$2 no ELF 64-bit LSB executable"
	fi

	sudo chmod +x "/usr/local/bin/$2"
}


#------------------------------------------------------------------------------
# M A I N
#------------------------------------------------------------------------------

_run_as_root 1
 
_install_docker
_download docker/compose docker-compose
_download docker/machine docker-machine
