#!/bin/ash

#------------------------------------------------------------------------------
function _log {
  echo "$1" > /proc/self/fd/1

  if test -f "/webhome/app/data/docker/docker.log"; then
    echo "$1" >> "/webhome/app/data/docker/docker.log"
  fi
}


#------------------------------------------------------------------------------
function _check {
  local TS=`date +'%Y-%m-%d %H:%M:%S'`
  local RE=

  if ! test -z "$2"; then
    if test -f "$2"; then
      local MY_PID=`cat "$2"`
      RE="[${MY_PID:0:1}]${MY_PID:1}"
    else
      _log "[$TS] PID File $2 of $1 missing"
      _restart_$1
    fi
  else
    RE="[${1:0:1}]${1:1}"
  fi

  if ! test -z "$RE"; then
    local IS_RUNNING=`ps aux | grep -E "$RE"`

    if test -z "$IS_RUNNING"; then
      _log "[$TS] ps aux $1 failed"
      _restart_$1
    fi
  fi

  if ! test -z "$3"; then
    local IS_OPEN=`nc -z -v -w5 localhost "$3" 2>&1 > /dev/null | grep 'open'`

    if test -z "$IS_OPEN"; then
      _log "[$TS] $1 port $3 is not open"
      _restart_$1
    fi
  fi

  local HAS_LSOF=`lsof -n "$1"`
  if test -z "$HAS_LSOF"; then
    _log "[$TS] lsof -n $1 failed"
    _restart_$1
  fi
}


#------------------------------------------------------------------------------
function _restart_sshd {
  echo "restart sshd: /usr/sbin/sshd"
  /usr/sbin/sshd
}


#------------------------------------------------------------------------------
function _restart_mysqld {
  echo "restart mysqld: /usr/bin/mysqld_safe"
  /usr/bin/mysqld_safe
}


#------------------------------------------------------------------------------
function _restart_httpd {
  echo "restart httpd: /usr/sbin/httpd -k start"
  /usr/sbin/httpd -k start
}


#------------------------------------------------------------------------------
function _check_all {
  if test "$1" = "0"; then
    local TS=`date +'%Y-%m-%d %H:%M:%S'`
    _log "[$TS] check sshd, mysqld, httpd"
  fi

  _check "sshd" "/var/run/sshd.pid" 22
  _check "mysqld" "/var/run/mysqld/mysqld.pid" 
  _check "httpd" "" 80
}


#------------------------------------------------------------------------------
# M A I N
#------------------------------------------------------------------------------

_check_all 0

N=1
while sleep 60; do
  _check_all $(($N%60))
  N=$(($N+1))
done

