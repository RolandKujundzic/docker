#!/bin/bash

if ! test -s '/usr/local/lib/rkscript.sh'; then
	echo "download rkscript.sh as /usr/local/lib/rkscript.sh"
	sudo wget -qO '/usr/local/lib/rkscript.sh' 'https://raw.githubusercontent.com/RolandKujundzic/rkscript/master/lib/rkscript.sh'
fi

. '/usr/local/lib/rkscript.sh' || { echo -e "\nERROR: . /usr/local/lib/rkscript.sh\n"; exit 1; }


#--
# Install docker
#--
function installDocker {
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
		sudo usermod -a -G docker $SUDO_USER
	fi
}


#--
# Install docker-compose|machine
# @param compose|machine
#--
function downloadDocker {
	local prog="docker-$1"
	_github_latest "docker/$1" "$prog"
	local latest="${GITHUB_LATEST[$prog]}"
	local version=`uname -s`-`uname -m`

	test "${GITHUB_IS_LATEST[$prog]}" = "1" && { echo "latest $prog $latest is already installed"; return; }
	[[ -z "$latest" || -z "$version" ]] && _abort "download $prog failed"

	local url="https://github.com/docker/$1/releases/download/$latest/$prog-$version"
	echo "download $url"
	echo "curl -L '$url' > '/usr/local/bin/$prog'" 
	sudo sh -c "curl -L '$url' > '/usr/local/bin/$prog'" || _abort "download failed: $url"

	local is_elf=`file /usr/local/bin/$prog | grep -E 'ELF 64-bit LSB executable'`
	test -z "$is_elf" && _abort "/usr/local/bin/$prog no ELF 64-bit LSB executable"
	sudo chmod +x "/usr/local/bin/$prog"
}


#--
# M A I N
#--

APP_DESC="Install docker[-compose|-machine]"

_run_as_root 1
 
installDocker
downloadDocker compose
downloadDocker machine

