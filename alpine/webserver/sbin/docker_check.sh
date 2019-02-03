#!/bin/ash

#------------------------------------------------------------------------------
function _check {
  local RE=

  if ! test -z "$2"; then
    if test -f "$2"; then
      local MY_PID=`cat "$2"`
      RE="[${MY_PID:0:1}]${MY_PID:1}"
    else
      echo "PID File $2 of $1 missing"
    fi
  else
    RE="[${1:0:1}]${1:1}"
  fi

  local IS_RUNNING=
  if ! test -z "$RE"; then
    echo "grep $RE in ps aux"
    IS_RUNNING=`ps aux | grep -E "$RE"`
  fi

  if test -z "$IS_RUNNING"; then
		local TS=`date +'%Y-%m-%d %H:%M:%S'`
    echo "$1 is not running ($TS) - try restart: $3"
		$3
  fi
}

#------------------------------------------------------------------------------
# M A I N
#------------------------------------------------------------------------------

while sleep 60; do
  _check "sshd" "/var/run/sshd.pid" "/usr/sbin/sshd"
  _check "mysqld" "/var/run/mysqld/mysqld.pid" "/usr/bin/mysqld_safe"
  _check "httpd" "" "httpd -D FOREGROUND"
done

