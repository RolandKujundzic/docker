#!/bin/bash

#------------------------------------------------------------------------------
function _abort {
	echo -e "\nABORT: $1\n\n"
	exit 1
}


#------------------------------------------------------------------------------
function _check_is_running {
	if test -f /etc/init.d/$1; then 
		IS_RUNNING=`/etc/init.d/$1 status | grep "$2"` 

		if test -z "$IS_RUNNING"; then
			_abort "$1 is down"
		fi
	fi
}



#
# M A I N
#

while sleep 60; do
	_check_is_running ssh "is running"
	_check_is_running mysql "Uptime"
	_check_is_running apache2 "is running"
done

