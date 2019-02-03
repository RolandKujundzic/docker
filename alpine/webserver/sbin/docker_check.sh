#!/bin/ash

#------------------------------------------------------------------------------
function _check {
  local RE=

  if ! test -z "$2"; then
    if test -f "$2"; then
      local MY_PID=`cat "$2"`
      RE="[${MY_PID:0:1}]${MY_PID:1}"
    else
      echo "PID File $2 missing"
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
    echo "$1 is not running - kill all processes"
		ps x | awk {'{print $1}'} | awk 'NR > 1' | xargs kill
  fi
}

#------------------------------------------------------------------------------
# M A I N
#------------------------------------------------------------------------------

while sleep 10; do
  _check "sshd" "/var/run/sshd.pid"
  _check "mysqld" "/var/run/mysqld/mysqld.pid"
  _check "httpd"
done

