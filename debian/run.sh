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

START_SERVICE="ssh mysql nginx"
STATUS_IS_RUNNING="ssh nginx"

for a in $START_SERVICE; do 
	if test -f /etc/init.d/$a; then 
		/etc/init.d/$a start
	fi
done

mysql-create "$DB_NAME" "$DB_PASS"

while sleep 60; do

	for a in $STATUS_IS_RUNNING; do 
		_check_is_running $a "$a is running"
	done

	_check_is_running mysql "Uptime"
done

