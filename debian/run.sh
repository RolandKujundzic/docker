#!/bin/bash

START_SERVICE="ssh mysql"

for a in $START_SERVICE; do 
	if test -f /etc/init.d/$a; then 
		/etc/init.d/$a start
	fi
done

mysql-create "$DB_NAME" "$DB_PASS"

while sleep 60; do
	for a in $START_SERVICE; do 
		if test -f /etc/init.d/$a; then 
			STATUS=`/etc/init.d/$a status` # | grep Uptime (if mysql) 

			if test -z "$STATUS"; then
				echo "$a is down"
				exit 1
			fi
		fi
	done
done

