#!/usr/bin/env bash
#
# Copyright (c) 2017 - 2021 Roland Kujundzic <roland@kujundzic.de>
#
# shellcheck disable=SC1091,SC1001,SC1090,SC2009,SC2033,SC2034,SC2046,SC2048,SC2068,SC2086,SC2119,SC2120,SC2153,SC2154,SC2183,SC2206
#


test -z "$RKBASH_DIR" && RKBASH_DIR="$HOME/.rkbash/$$"

if declare -A __hash=([key]=value) 2>/dev/null; then
	test "${__hash[key]}" = 'value' || { echo -e "\nERROR: declare -A\n"; exit 1; }
	unset __hash
else
	echo -e "\nERROR: declare -A\n"
	exit 1  
fi  

if test "${@: -1}" = 'help' 2>/dev/null; then
	for a in ps tr xargs head grep awk find sed sudo cd chown chmod mkdir rm ls; do
		command -v $a >/dev/null || { echo -e "\nERROR: missing $a\n"; exit 1; }
	done
fi

function _abort {
	local msg line rf brf nf
	rf="\033[0;31m"
	brf="\033[1;31m"
	nf="\033[0m"

	msg="$1"
	if test -n "$2"; then
		msg="$2"
		line="[$1]"
	fi

	if test "$NO_ABORT" = 1; then
		ABORT=1
		echo -e "${rf}WARNING${line}: ${msg}${nf}"
		return 1
	fi

	msg="${rf}${msg}${nf}"

	local frame trace 
	if type -t caller >/dev/null 2>/dev/null; then
		frame=0
		trace=$(while caller $frame; do ((frame++)); done)
		msg="$msg\n\n$trace"
	fi

	if [[ -n "$LOG_LAST" && -s "$LOG_LAST" ]]; then
		msg="$msg\n\n$(tail -n+5 "$LOG_LAST")"
	fi

	test -n "$ABORT_MSG" && msg="$msg\n\n$ABORT_MSG" 

	echo -e "\n${brf}ABORT${line}:${nf} $msg\n" 1>&2

	local other_pid=

	if test -n "$APP_PID"; then
		for a in $APP_PID; do
			other_pid=$(ps aux | grep -E "^.+\\s+$a\\s+" | awk '{print $2}')
			test -z "$other_pid" || kill "$other_pid" 2>/dev/null 1>&2
		done
	fi

	if test -n "$APP"; then
		other_pid=$(ps aux | grep "$APP" | awk '{print $2}')
		test -z "$other_pid" || kill "$other_pid" 2>/dev/null 1>&2
	fi

	exit 1
}


function _add_abort_linenum {
	local lines changes tmp_file fix_line
	type -t caller >/dev/null 2>/dev/null && return

	_mkdir "$RKBASH_DIR/add_abort_linenum"
	tmp_file="$RKBASH_DIR/add_abort_linenum/"$(basename "$1")
	test -f "$tmp_file" && _abort "$tmp_file already exists"

	echo -n "add line number to _abort in $1"
	changes=0

	readarray -t lines < "$1"
	for ((i = 0; i < ${#lines[@]}; i++)); do
		fix_line=$(echo "${lines[$i]}" | grep -E -e '(;| \|\|| &&) _abort ["'"']" -e '^\s*_abort ["'"']" | grep -vE -e '^\s*#' -e '^\s*function ')
		if test -z "$fix_line"; then
			echo "${lines[$i]}" >> "$tmp_file"
		else
			changes=$((changes+1))
			echo "${lines[$i]}" | sed -E 's/^(.*)_abort (.+)$/\1_abort '$((i+1))' \2/g' >> "$tmp_file"
		fi
	done

	echo " ($changes)"
	_cp "$tmp_file" "$1" >/dev/null
}


function _apt_install {
	local curr_lne
	curr_lne=$LOG_NO_ECHO
	LOG_NO_ECHO=1

	_require_program apt
	_run_as_root 1
	_rkbash_dir

	for a in $*; do
		if test -d "$RKBASH_DIR/apt/$a"; then
			_msg "already installed, skip: apt -y install $a"
		else
			sudo apt -y install "$a" || _abort "apt -y install $a"
			_log "apt -y install $a" "apt/$a"
		fi
	done

	_rkbash_dir reset
	LOG_NO_ECHO=$curr_lne
}


function _cd {
	local has_realpath curr_dir goto_dir
	has_realpath=$(command -v realpath)

	if [[ -n "$has_realpath" && -n "$1" ]]; then
		curr_dir=$(realpath "$PWD")
		goto_dir=$(realpath "$1")

		if test "$curr_dir" = "$goto_dir"; then
			return
		fi
	fi

	test -z "$2" && _msg "cd '$1'"

	if test -z "$1"; then
		if test -n "$LAST_DIR"; then
			_cd "$LAST_DIR"
			return
		else
			_abort "empty directory path"
		fi
	fi

	if ! test -d "$1"; then
		_abort "no such directory [$1]"
	fi

	LAST_DIR="$PWD"

	cd "$1" || _abort "cd '$1' failed"
}


function _chmod {
	local tmp cmd i priv
	test -z "$1" && _abort "empty privileges parameter"
	test -z "$2" && _abort "empty path"

	tmp=$(echo "$1" | sed -E 's/[012345678]*//')
	test -z "$tmp" || _abort "invalid octal privileges '$1'"

	cmd="chmod -R"
	if test -n "$CHMOD"; then
		cmd="$CHMOD"
		CHMOD=
	fi

	if test -z "$2"; then
		for ((i = 0; i < ${#FOUND[@]}; i++)); do
			priv=

			if test -f "${FOUND[$i]}" || test -d "${FOUND[$i]}"; then
				priv=$(stat -c "%a" "${FOUND[$i]}")
			fi

			if test "$1" != "$priv" && test "$1" != "0$priv"; then
				_sudo "$cmd $1 '${FOUND[$i]}'" 1
			fi
		done
	elif test -f "$2"; then
		priv=$(stat -c "%a" "$2")

		if [[ "$1" != "$priv" && "$1" != "0$priv" ]]; then
			_sudo "$cmd $1 '$2'" 1
		fi
	elif test -d "$2"; then
		_sudo "$cmd $1 '$2'" 1
	fi
}


function _confirm {
	local msg
	msg="\033[0;35m$1\033[0m"

	CONFIRM=

	if test -n "$AUTOCONFIRM"; then
		CONFIRM="${AUTOCONFIRM:0:1}"
		echo -e "$msg <$CONFIRM>"
		AUTOCONFIRM="${AUTOCONFIRM:1}"
		return
	fi

	if test -z "$CONFIRM_COUNT"; then
		CONFIRM_COUNT=1
	else
		CONFIRM_COUNT=$((CONFIRM_COUNT + 1))
	fi

	local flag cckey default

	flag=$(($2 + 0))

	if test $((flag & 2)) = 2; then
		if test $((flag & 1)) = 1; then
			CONFIRM=n
		else
			CONFIRM=y
		fi

		return
	fi

	while read -r -d $'\0' 
	do
		cckey="--q$CONFIRM_COUNT"
		if test "$REPLY" = "$cckey=y"; then
			echo "found $cckey=y, accept: $1" 
			CONFIRM=y
		elif test "$REPLY" = "$cckey=n"; then
			echo "found $cckey=n, reject: $1" 
			CONFIRM=n
		fi
	done < /proc/$$/cmdline

	if test -n "$CONFIRM"; then
		CONFIRM_TEXT="$CONFIRM"
		return
	fi

	if test $((flag & 1)) -ne 1; then
		default=n
		echo -n -e "$msg  y [n]  "
		read -r -n1 -t 10 CONFIRM
		echo
	else
		default=y
		echo -n -e "$msg  \033[0;35m[y]\033[0m n  "
		read -r -n1 -t 3 CONFIRM
		echo
	fi

	if test -z "$CONFIRM"; then
		CONFIRM="$default"
	fi

	CONFIRM_TEXT="$CONFIRM"

	if test "$CONFIRM" != "y"; then
		CONFIRM=n
  fi
}


function _cp {
	local curr_lno target_dir md1 md2 pdir
	curr_lno="$LOG_NO_ECHO"
	LOG_NO_ECHO=1

	CP_FIRST=
	CP_KEEP=

	test -z "$2" && _abort "empty target"

	target_dir=$(dirname "$2")
	test -d "$target_dir" || _abort "no such directory [$target_dir]"

	if test "$3" != 'md5'; then
		:
	elif ! test -f "$2"; then
		CP_FIRST=1
	elif test -f "$1"; then
		md1=$(_md5 "$1")
		md2=$(_md5 "$2")

		if test "$md1" = "$md2"; then
			_msg "_cp: keep $2 (same as $1)"
			CP_KEEP=1
		else
			_msg "Copy file $1 to $2 (update)"
			_sudo "cp '$1' '$2'" 1
		fi

		return
	fi

	if test -f "$1"; then
		_msg "Copy file $1 to $2"
		_sudo "cp '$1' '$2'" 1
	elif test -d "$1"; then
		if test -d "$2"; then
			pdir="$2"
			_confirm "Remove existing target directory '$2'?"
			if test "$CONFIRM" = "y"; then
				_rm "$pdir"
				_msg "Copy directory $1 to $2"
				_sudo "cp -r '$1' '$2'" 1
			else
				_msg "Copy directory $1 to $2 (use rsync)" 
				_rsync "$1/" "$2"
			fi
		else
			_msg "Copy directory $1 to $2"
			_sudo "cp -r '$1' '$2'" 1
		fi
	else
		_abort "No such file or directory [$1]"
	fi

	LOG_NO_ECHO="$curr_lno"
}


function _docker_rm {
	_docker_stop "$1"

	if test -n "$(docker ps -a | grep "$1")"; then
		echo "docker rm $1"
		docker rm "$1"
	fi
}


function _docker_run {
	_docker_rm "$1"

	if [[ -n "$WORKSPACE" && -n "$CURR" && -d "$WORKSPACE/linux/rkdocker" ]]; then
		_cd "$WORKSPACE/linux/rkdocker"
	else
		_abort "Export WORKSPACE (where $WORKSPACE/linux/rkdocker exists) and CURR=path/current/directory"
	fi

	local config

	if test -f "$CURR/$2"; then
		config="$CURR/$2"
	elif test -f "$2"; then
		config="$2"
	else
		_abort "No such configuration $CURR/$2 ($PWD/$2)"
	fi
	
  echo "DOCKER_NAME=$1 ./run.sh $config start"
  DOCKER_NAME=$1 ./run.sh $2 start

	_cd "$CURR"
}


function _docker_stop {
	if test -n "$(docker ps | grep "$1")"; then
		echo "docker stop $1"
		docker stop "$1"
	fi
}


function _find {
	FOUND=()
	local a

	_require_program find
	_require_dir "$1"

	while read -r a; do
		FOUND+=("$a")
	done < <(eval "find '$1' $2" || _abort "find '$1' $2")
}


function _is_running {
	_os_type linux
	local rx out res
	res=0

	if test "$1" = 'apache'; then
		rx='[a]pache2.*k start'
	elif test "$1" = 'nginx'; then
		rx='[n]ginx.*master process'
	elif test "${1:0:7}" = 'docker:'; then
		rx="[d]ocker-proxy.* -host-port ${1:7}"
	elif test "${1:0:5}" = 'port:'; then
		out=$(netstat -tulpn 2>/dev/null | grep -E ":${1:5} .+:* .+LISTEN.*")
	else
		_abort "invalid [$1] use apache|nginx|docker:PORT|port:N|rx:[n]ame"
	fi

	test -z "$rx" || out=$(ps aux 2>/dev/null | grep -E "$rx")

	test -z "$out" && res=1
	return $res	
}


declare -Ai LOG_COUNT  # define hash (associative array) of integer
declare -A LOG_FILE  # define hash
declare -A LOG_CMD  # define hash
LOG_NO_ECHO=

function _log {
	test -z "$LOG_NO_ECHO" && _msg "$1" -n
	
	if test -z "$2"; then
		test -z "$LOG_NO_ECHO" && echo
		return
	fi

	LOG_COUNT[$2]=$((LOG_COUNT[$2] + 1))
	LOG_FILE[$2]="$RKBASH_DIR/$2/${LOG_COUNT[$2]}.nfo"
	LOG_CMD[$2]=">>'${LOG_FILE[$2]}' 2>&1"
	LOG_LAST=

	if ! test -d "$RKBASH_DIR/$2"; then
		mkdir -p "$RKBASH_DIR/$2"
		if test -n "$SUDO_USER"; then
			chown -R $SUDO_USER.$SUDO_USER "$RKBASH_DIR" || _abort "chown -R $SUDO_USER.$SUDO_USER '$RKBASH_DIR'"
		elif test "$UID" = "0"; then
			chmod -R 777 "$RKBASH_DIR" || _abort "chmod -R 777 '$RKBASH_DIR'"
		fi
	fi

	local now
	now=$(date +'%d.%m.%Y %H:%M:%S')
	echo -e "# _$2: $now\n# $PWD\n# $1 ${LOG_CMD[$2]}\n" > "${LOG_FILE[$2]}"

	if test -n "$SUDO_USER"; then
		chown $SUDO_USER.$SUDO_USER "${LOG_FILE[$2]}" || _abort "chown $SUDO_USER.$SUDO_USER '${LOG_FILE[$2]}'"
	elif test "$UID" = "0"; then
		chmod 666 "${LOG_FILE[$2]}" || _abort "chmod 666 '${LOG_FILE[$2]}'"
	fi

	test -z "$LOG_NO_ECHO" && _msg " ${LOG_CMD[$2]}"
	test -s "${LOG_FILE[$2]}" && LOG_LAST="${LOG_FILE[$2]}"
}


function _md5 {
	_require_program md5sum
	
	if test -z "$1"; then
		_abort "Empty parameter"
	elif test -f "$1"; then
		md5sum "$1" | awk '{print $1}'
	elif test "$2" = "1"; then
		echo -n "$1" | md5sum | awk '{print $1}'
	else
		_abort "No such file [$1]"
	fi
}


function _merge_sh {
	local a my_app mb_app sh_dir rkbash_inc tmp_app md5_new md5_old inc_sh scheck
	my_app="${1:-$APP}"
	sh_dir="${my_app}_"

	if test -n "$2"; then
		my_app="$2"
		sh_dir="$1"
	else
		_require_file "$my_app"
		mb_app=$(basename "$my_app")
		test -d "$sh_dir" || { test -d "$mb_app" && sh_dir="$mb_app"; }
	fi

	test "${ARG[static]}" = "1" && rkbash_inc=$(_merge_static "$sh_dir")

	_require_dir "$sh_dir"

	tmp_app="$sh_dir"'_'
	test -s "$my_app" && md5_old=$(_md5 "$my_app")
	_msg "merge $sh_dir into $my_app ... " -n

	inc_sh=$(find "$sh_dir" -name '*.inc.sh' 2>/dev/null | sort)
	scheck=$(grep -E '^# shellcheck disable=' $inc_sh | sed -E 's/.+ disable=(.+)$/\1/g' | tr ',' ' ' | xargs -n1 | sort -u | xargs | tr ' ' ',')
	test -z "$scheck" || RKS_HEADER_SCHECK="shellcheck disable=SC1091,$scheck"

	if test -z "$rkbash_inc"; then
		_rks_header "$tmp_app" 1
	else
		_rks_header "$tmp_app"
		echo "$rkbash_inc" >> "$tmp_app"
	fi

	for a in $inc_sh; do
		tail -n+2 "$a" | grep -E -v '^# shellcheck disable=' >> "$tmp_app"
	done

	_add_abort_linenum "$tmp_app"

	md5_new=$(_md5 "$tmp_app")
	if test "$md5_old" = "$md5_new"; then
		_msg "no change"
		_rm "$tmp_app" >/dev/null
	else
		_msg "update"
		_mv "$tmp_app" "$my_app"
		_chmod 755 "$my_app"
	fi

	test -z "$2" && exit 0
}


function _merge_static {
	local a rks_inc inc_sh
	inc_sh=$(find "$1" -name '*.inc.sh' 2>/dev/null | sort)

	for a in $inc_sh; do
		_rkbash_inc "$a"
		rks_inc="$rks_inc $RKBASH_INC"
	done

	for a in $(_sort $rks_inc); do
		tail -n +2 "$RKBASH_SRC/${a:1}.sh" | grep -E -v '^\s*#'
	done
}


function _mkdir {
	local flag
	flag=$(($2 + 0))

	test -z "$1" && _abort "Empty directory path"

	if test -d "$1"; then
		test $((flag & 1)) = 1 && _abort "directory $1 already exists"
		test $((flag & 4)) = 4 && _msg "directory $1 already exists"
	else
		_msg "mkdir -p $1"
		$SUDO mkdir -p "$1" || _abort "mkdir -p '$1'"
	fi

	test $((flag & 2)) = 2 && _chmod 777 "$1"
}


function _msg {
	if test "$2" == '-n'; then
		echo -n -e "\033[0;2m$1\033[0m"
	else
		echo -e "\033[0;2m$1\033[0m"
	fi
}


function _mv {

	if test -z "$1"; then
		_abort "Empty source path"
	fi

	if test -z "$2"; then
		_abort "Empty target path"
	fi

	local pdir
	pdir=$(dirname "$2")
	if ! test -d "$pdir"; then
		_abort "No such directory [$pdir]"
	fi

	local AFTER_LAST_SLASH=${1##*/}

	if test "$AFTER_LAST_SLASH" = "*"
	then
		_msg "mv $1 $2"
		mv "$1" "$2" || _abort "mv $1 $2 failed"
	else
		_msg "mv '$1' '$2'"
		mv "$1" "$2" || _abort "mv '$1' '$2' failed"
	fi
}


function _ok {
	echo -e "\033[0;32m$1\033[0m" 1>&2
}


function _os_type {
	local os me

	_require_program uname
	me=$(uname -s)

	if [ "$(uname)" = "Darwin" ]; then
		os="macos"        
	elif [ "$OSTYPE" = "linux-gnu" ]; then
		os="linux"
	elif [ "${me:0:5}" = "Linux" ]; then
		os="linux"
	elif [ "${me:0:5}" = "MINGW" ]; then
		os="cygwin"
	fi

	if test -z "$1"; then
		echo $os
	elif test "$1" != "$os"; then
		_abort "$1 required (this is $os)"
	fi

	return 0
}


declare -A ARG
declare ARGV

function _parse_arg {
	test "${#ARG[@]}" -gt 0 && return
	ARGV=()

	local i n key val
	n=0
	for (( i = 0; i <= $#; i++ )); do
		ARGV[$i]="${!i}"
		val="${!i}"
		key=

		if [[ "$val" =~ ^\-?\-?[a-zA-Z0-9_\.\-]+= ]]; then
			key="${val/=*/}"
			val="${val#*=}"
			test "${key:0:2}" = '--' && key="${key:2}"
			test "${key:0:1}" = '-' && key="${key:1}"
		elif [[ "$val" =~ ^\-\-[[a-zA-Z0-9_\.\-]+$ ]]; then
			key="${val:2}"
			val=1
		fi

		if test -z "$key"; then
			ARG[$n]="$val"
			n=$(( n + 1 ))
		elif test -z "${ARG[$key]}"; then
			ARG[$key]="$val"
		else
			ARG[$key]="${ARG[$key]} $val"
		fi
	done

	ARG[#]=$n
}


function _require_dir {
	test -d "$1" || _abort "no such directory '$1'"
	test -z "$2" || _require_owner "$1" "$2"
	test -z "$3" || _require_priv "$1" "$3"
}


function _require_file {
	test -f "$1" || _abort "no such file '$1'"
	test -z "$2" || _require_owner "$1" "$2"
	test -z "$3" || _require_priv "$1" "$3"
}


function _require_global {
	local a has_hash bash_version
	bash_version=$(bash --version | grep -iE '.+bash.+version [0-9\.]+' | sed -E 's/^.+version ([0-9]+)\.([0-9]+)\..+$/\1.\2/i')

	for a in "$@"; do
		has_hash="HAS_HASH_$a"

		if (( $(echo "$bash_version >= 4.4" | bc -l) )); then
			typeset -n ARR=$a

			if test -z "$ARR" && test -z "${ARR[@]:1:1}"; then
				_abort "no such global variable $a"
			fi
		elif test -z "${a}" && test -z "${has_hash}"; then
			_abort "no such global variable $a - add HAS_HASH_$a if necessary"
		fi
	done
}


function _require_owner {
	if ! test -f "$1" && ! test -d "$1"; then
		_abort "no such file or directory '$1'"
	fi

	local arr owner group
	arr=( ${2//:/ } )
	owner=$(stat -c '%U' "$1" 2>/dev/null)
	test -z "$owner" && _abort "stat -c '%U' '$1'"
	group=$(stat -c '%G' "$1" 2>/dev/null)
	test -z "$group" && _abort "stat -c '%G' '$1'"

	if [[ -n "${arr[0]}" && "${arr[0]}" != "$owner" ]]; then
		_abort "invalid owner - chown ${arr[0]} '$1'"
	fi

	if [[ -n "${arr[1]}" && "${arr[1]}" != "$group" ]]; then
		_abort "invalid group - chgrp ${arr[1]} '$1'"
	fi
}


function _require_priv {
	test -z "$2" && _abort "empty privileges"
	local priv
	priv=$(stat -c '%a' "$1" 2>/dev/null)
	test -z "$priv" && _abort "stat -c '%a' '$1'"
	test "$2" = "$priv" || _abort "invalid privileges [$priv] - chmod -R $2 '$1'"
}


function _require_program {
	local ptype
	ptype=$(type -t "$1")

	test "$ptype" = "function" && return 0
	command -v "$1" >/dev/null 2>&1 && return 0
	command -v "./$1" >/dev/null 2>&1 && return 0

	if test "${2:0:4}" = "apt:"; then
		_apt_install "${2:4}"
		return 0
	fi

	[[ -n "$2" || "$NO_ABORT" = 1 ]] && return 1

	local frame trace 
	if type -t caller >/dev/null 2>/dev/null; then
		frame=0
		trace=$(while caller $frame; do ((frame++)); done)
	fi

	echo -e "\n\033[1;31mABORT:\033[0m \033[0;31mNo such program [$1]\033[0m\n\n$trace\n" 1>&2
	exit 1
}


function _rkbash_dir {
	if [[ "$RKBASH_DIR" = "$HOME/.rkbash" && "$1" = 'reset' ]]; then
		RKBASH_DIR="$HOME/.rkbash/$$"
		return
	fi

	if [[ "$RKBASH_DIR" != "$HOME/.rkbash/$$" ]]; then
		:
	elif test -z "$1"; then
		RKBASH_DIR="$HOME/.rkbash"
	elif [[ "$1" != 'reset' ]]; then
		RKBASH_DIR="$HOME/.rkbash/$1"
		_mkdir "$RKBASH_DIR"
	fi
}
	

function _rkbash_inc {
	local _HAS_SCRIPT
	declare -A _HAS_SCRIPT

	if test -z "$RKBASH_SRC"; then
		if test -s "src/abort.sh"; then
			RKBASH_SRC='src'
		else
			_abort 'set RKBASH_SRC'
		fi
	elif ! test -s "$RKBASH_SRC/abort.sh"; then
		_abort "invalid RKBASH_SRC='$RKBASH_SRC'"
	fi

	test -s "$1" || _abort "no such file '$1'"
	_rrs_scan "$1"

	RKBASH_INC=$(_sort ${!_HAS_SCRIPT[@]})
	RKBASH_INC_NUM="${#_HAS_SCRIPT[@]}"
}


function _rrs_scan {
	local a func_list
	test -f "$1" || _abort "no such file '$1'"
	func_list=$(grep -E -o -e '(_[a-z0-9\_]+)' "$1" | xargs -n1 | sort -u | xargs)

	for a in $func_list; do
		if [[ -z "${_HAS_SCRIPT[$a]}" && -s "$RKBASH_SRC/${a:1}.sh" ]]; then
			_HAS_SCRIPT[$a]=1
			_rrs_scan "$RKBASH_SRC/${a:1}.sh"
		fi
	done
}


function _rks_app {
	_parse_arg "$@"

	local me p1 p2 p3
	me="$0"
	p1="$1"
	p2="$2"
	p3="$3"

	test -z "$me" && _abort 'call _rks_app "$@"'
	test -z "${ARG[1]}" || p1="${ARG[1]}"
	test -z "${ARG[2]}" || p2="${ARG[2]}"
	test -z "${ARG[3]}" || p3="${ARG[3]}"

	if test -z "$APP"; then
		APP="$me"
		APP_DIR=$( cd "$( dirname "$APP" )" >/dev/null 2>&1 && pwd )
		CURR="$PWD"
		if test -z "$APP_PID"; then
			 export APP_PID="$$"
		elif test "$APP_PID" != "$$"; then
			 export APP_PID="$APP_PID $$"
		fi
	fi

	test -z "${#SYNTAX_CMD[@]}" && _abort "SYNTAX_CMD is empty"
	test -z "${#SYNTAX_HELP[@]}" && _abort "SYNTAX_HELP is empty"

	[[ "$p1" =	'self_update' ]] && _merge_sh

	[[ "$p1" = 'help' ]] && _syntax "*" "cmd:* help:*"
	test -z "$p1" && return

	test -n "${SYNTAX_HELP[$p1]}" && APP_DESC="${SYNTAX_HELP[$p1]}"
	[[ -n "$p2" && -n "${SYNTAX_HELP[$p1.$p2]}" ]] && APP_DESC="${SYNTAX_HELP[$p1.$p2]}"

	[[ -n "$p2" && -n "${SYNTAX_CMD[$p1.$p2]}" && ("$p3" = 'help' || "${ARG[help]}" = '1') ]] && \
		_syntax "$p1.$p2" "help:"

	[[ -n "${SYNTAX_CMD[$p1]}" && ("$p2" = 'help' || "${ARG[help]}" = '1') ]] && \
		_syntax "$p1" "help:"

	test "${ARG[help]}" = '1' && _syntax "*" "cmd:* help:*"
}


function _rks_header {
	local flag header copyright
	copyright=$(date +"%Y")
	flag=$(($2 + 0))

	[ -z "${RKS_HEADER+x}" ] || flag=$((RKS_HEADER + 0))

	if test -f ".gitignore"; then
		copyright=$(git log --diff-filter=A -- .gitignore | grep 'Date:' | sed -E 's/.+ ([0-9]+) \+[0-9]+/\1/')" - $copyright"
	fi

	test $((flag & 1)) = 1 && \
		header='source /usr/local/lib/rkbash.lib.sh || { echo -e "\nERROR: source /usr/local/lib/rkbash.lib.sh\n"; exit 1; }'

	printf '\x23!/usr/bin/env bash\n\x23\n\x23 Copyright (c) %s Roland Kujundzic <roland@kujundzic.de>\n\x23\n\x23 %s\n\x23\n\n' \
		"$copyright" "$RKS_HEADER_SCHECK" > "$1"
	test -z "$header" || echo "$header" >> "$1"
}


function _rm {
	test -z "$1" && _abort "Empty remove path"

	if ! test -f "$1" && ! test -d "$1"; then
		test -z "$2" || _abort "No such file or directory '$1'"
	else
		_msg "remove '$1'"
		rm -rf "$1" || _abort "rm -rf '$1'"
	fi
}


function _rsync {
	local target="$2"
	test -z "$target" && target="."

	test -z "$1" && _abort "Empty rsync source"
	test -d "$target" || _abort "No such directory [$target]"

	local rsync="rsync -av $3 -e ssh '$1' '$2'"
	local error
	_log "$rsync" rsync
	eval "$rsync ${LOG_CMD[rsync]}" || error=1

	if test "$error" = "1"; then
		test -z "$(tail -4 "${LOG_FILE[rsync]}" | grep 'speedup is ')" && _abort "$rsync"
		test -z "$(tail -1 "${LOG_FILE[rsync]}" | grep "rsync error:")" || \
			_warn "FIX rsync errors in ${LOG_FILE[rsync]}"
	fi
}


function _run_as_root {
	test "$UID" = "0" && return

	if test -z "$1"; then
		_abort "Please change into root and try again"
	else
		echo "sudo true - you might need to type in your password"
		sudo true 2>/dev/null || _abort "sudo true failed - Please change into root and try again"
	fi
}


function _service {
	test -z "$1" && _abort "empty service name"
	test -z "$2" && _abort "empty action"

	local is_active
	is_active=$(systemctl is-active "$1")

	if [[ "$is_active" != 'active' && ! "$2" =~ start && ! "$2" =~ able ]]; then
		_abort "$is_active service $1"
	fi

	if test "$2" = 'status'; then
		_ok "$1 is active"
		return
	fi

	_msg "systemctl $2 $1"
	_sudo "systemctl $2 $1"
}


function _sort {
	echo "$@" | xargs -n1 | sort -u | xargs
}


function _stop_http {
	_os_type linux

	if ! _is_running port:80; then
		_warn "no service on port 80"
		return
	fi

	if _is_running docker:80; then
		_warn "ignore docker service on port 80"
		return
	fi

	if _is_running nginx; then
		_service nginx stop
	elif _is_running apache; then
		_service apache2 stop
	fi
}


function _sudo {
	local curr_sudo exec flag
	curr_sudo="$SUDO"

	exec="$1"

	flag=$(($2 + 0))

	if test "$USER" = "root"; then
		_log "$exec" sudo
		eval "$exec ${LOG_CMD[sudo]}" || _abort "$exec"
	elif test $((flag & 1)) = 1 && test -z "$curr_sudo"; then
		_log "$exec" sudo
		eval "$exec ${LOG_CMD[sudo]}" || \
			( _msg "try sudo $exec"; eval "sudo $exec ${LOG_CMD[sudo]}" || _abort "sudo $exec" )
	else
		SUDO=sudo
		_log "sudo $exec" sudo
		eval "sudo $exec ${LOG_CMD[sudo]}" || _abort "sudo $exec"
		SUDO="$curr_sudo"
	fi

	LOG_LAST=
}


declare -A SYNTAX_CMD
declare -A SYNTAX_HELP

function _syntax {
	local a msg old_msg desc base syntax
	msg=$(_syntax_cmd "$1") 
	syntax="\n\033[1;31mSYNTAX:\033[0m"

	for a in $2; do
		old_msg="$msg"

		if test "${a:0:4}" = "cmd:"; then
			test "$a" = "cmd:" && a="cmd:$1"
			msg="$msg $(_syntax_cmd_other "$a")"
		elif test "${a:0:5}" = "help:"; then
			test "$a" = "help:" && a="help:$1"
			msg="$msg $(_syntax_help "${a:5}")"
		fi

		test "$old_msg" != "$msg" && msg="$msg\n"
	done

	test "${msg: -3:1}" = '|' && msg="${msg:0:-3}\n"

	base=$(basename "$APP")
	if test -n "$APP_PREFIX"; then
		echo -e "$syntax $(_warn_msg "$APP_PREFIX $base $msg")" 1>&2
	else
		echo -e "$syntax $(_warn_msg "$base $msg")" 1>&2
	fi

	for a in APP_DESC APP_DESC_2 APP_DESC_3 APP_DESC_4; do
		test -z "${!a}" || desc="$desc${!a}\n\n"
	done
	echo -e "$desc" 1>&2

	exit 1
}


function _syntax_cmd {
	local a rx msg keys prefix
	keys=$(_sort "${!SYNTAX_CMD[@]}")
	msg="$1\n" 

	if test -n "${SYNTAX_CMD[$1]}"; then
		msg="${SYNTAX_CMD[$1]}\n"
	elif test "${1: -1}" = "*" && test "${#SYNTAX_CMD[@]}" -gt 0; then
		if test "$1" = "*"; then
			rx='^[a-zA-Z0-9_]+$'
		else
			prefix="${1:0:-1}"
			rx="^${1:0:-2}"'\.[a-zA-Z0-9_\.]+$'
		fi

		msg=
		for a in $keys; do
			grep -E "$rx" >/dev/null <<< "$a" && msg="$msg|${a/$prefix/}"
		done
		msg="${msg:1}\n"
	elif [[ "$1" = *'.'* && -n "${SYNTAX_CMD[${1%%.*}]}" ]]; then
		msg="${SYNTAX_CMD[${1%%.*}]}\n"
	fi

	echo "$msg"
}


function _syntax_cmd_other {
	local a rx msg keys base
	keys=$(_sort "${!SYNTAX_CMD[@]}")
	rx="$1"

	test "${rx:4}" = "*" && rx='^[a-zA-Z0-9_]+$' || rx="^${rx:4:-2}"'\.[a-zA-Z0-9_]+$'

	base=$(basename "$APP")
	for a in $keys; do
		grep -E "$rx" >/dev/null <<< "$a" && msg="$msg\n$base ${SYNTAX_CMD[$a]}"
	done

	echo "$msg"
}


function _syntax_help {
	local a rx msg keys prefix
	keys=$(_sort "${!SYNTAX_HELP[@]}")

	if test "$1" = '*'; then
		rx='^[a-zA-Z0-9_]+$'
	elif test "${1: -1}" = '*'; then
		rx="^${rx: -2}"'\.[a-zA-Z0-9_\.]+$'
	fi

	for a in $keys; do
		if test "$a" = "$1"; then
			msg="$msg\n${SYNTAX_HELP[$a]}"
		elif test -n "$rx" && grep -E "$rx" >/dev/null <<< "$a"; then
			prefix=$(sed -E 's/^[a-zA-Z0-9_]+\.//' <<< "$a")
			msg="$msg\n$prefix: ${SYNTAX_HELP[$a]}\n"
		fi
	done

	[[ -n "$msg" && "$msg" != "\n$APP_DESC" ]] && echo -e "$msg"
}


function _version {
	local flag version
	flag=$(($2 + 0))

	if [[ "$1" =~ ^v?[0-9\.]+$ ]]; then
		version="$1"
	elif command -v "$1" &>/dev/null; then
		version=$({ $1 --version || _abort "$1 --version"; } | head -1 | grep -E -o 'v?[0-9]+\.[0-9\.]+')
	fi

	version="${version/v/}"

	[[ "$version" =~ ^[0-9\.]+$ ]] || _abort "version detection failed ($1)"

	if [[ $((flag & 1)) = 1 ]]; then
		if [[ "$version" =~ ^[0-9]{1,2}\.[0-9]{1,2}$ ]]; then
			printf "%d%02d" $(echo "$version" | tr '.' ' ')
		elif [[ "$version" =~ ^[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}$ ]]; then
			printf "%d%02d%02d" $(echo "$version" | tr '.' ' ')
		else
			_abort "failed to convert $version to number"
		fi
	elif [[ $((flag & 2)) ]]; then
		echo -n "${version%%.*}"
	elif [[ $((flag & 4)) ]]; then
		echo -n "${version%.*}"
	else
		echo -n "$version"
	fi
}


function _warn {
	echo -e "\033[0;31m$1\033[0m" 1>&2
}


function _warn_msg {
	local line first
	while IFS= read -r line; do
		if test "$first" = '1'; then
			echo "$line"
		else
			echo '\033[0;31m'"$line"'\033[0m'
			first=1
		fi
	done <<< "${1//\\n/$'\n'}"
}

# shellcheck disable=SC2034,SC2086,SC2154,SC1090

#---
# Export DOCKER_RUN. Create sql:admin mysql account. Set UID and GID 
# if /etc/passwd exists. Mount DOCROOT_SOURCE to /webhome/DOCKER_NAME (=DOCROOT_TARGET)
# or /path/to/Desktop/workspace to /docker/workspace. Append DOCKER_PARAMETER
# to DOCKER_RUN.
#
# @global DOCROOT_SOURCE DOCKER_NAME DOCROOT_TARGET
# @export DOCKER_RUN
#---
function export_docker_run {
	local dmount set_uid sed_gid uid_gid
	if ! test -z "$DOCROOT_SOURCE" && test -d "$DOCROOT_SOURCE"; then
		test -z "$DOCROOT_TARGET" && DOCROOT_TARGET="/webhome/$DOCKER_NAME"
  	dmount="--mount type=bind,source=$DOCROOT_SOURCE,target=$DOCROOT_TARGET"
	elif test -d "/Users/$USER/Desktop/workspace"; then
  	dmount="--mount type=bind,source=/Users/$USER/Desktop/workspace,target=/docker/workspace"
	elif test -d "/home/$USER/Desktop/workspace"; then
  	dmount="--mount type=bind,source=/home/$USER/Desktop/workspace,target=/docker/workspace"
	fi

	if test -f /etc/passwd; then
  	set_uid=$(id -u)
  	set_gid=$(id -g)

  	if test "$set_gid" -ge 1000 && test "$set_uid" -ge 1000
  	then
    	uid_gid="-e set_uid=$set_uid -e set_gid=$set_gid"
  	fi
	fi

	DOCKER_RUN="-d -e SQL_PASS=admin $dmount $uid_gid $DOCKER_PARAMETER"
}


#---
# M A I N
#---

APP_DESC='Control docker. Autodetect name unless: DOCKER_NAME=MyContainer ./run.sh …'

_rks_app "$@"

test -f "${ARG[1]}" || _syntax "path/to/config.sh build|start|stop|show|run"
source "${ARG[1]}" || _abort "load configuration ${ARG[1]} failed"

CONFIG_DIR=$(dirname "${ARG[1]}")

_require_global DOCKER_IMAGE

[[ "${ARG[2]}" = "start" || "${ARG[2]}" = "run" || "${ARG[2]}" = "show" ]] && export_docker_run

if [[ "${ARG[2]}" = "build" && ! -f "$CONFIG_DIR/$DOCKER_DF" ]]; then
	if test -z "$DOCKER_DF" && test -s "$CONFIG_DIR/Dockerfile"; then
		DOCKER_DF=Dockerfile
	else
		_abort "export DOCKER_DF=Dockerfile in ${ARG[1]}"
	fi
elif test -z "$DOCKER_NAME"; then
	DOCKER_NAME=$(basename "${ARG[1]}" | sed -E 's/\.sh$//')
	_confirm "Use DOCKER_NAME=$DOCKER_NAME" 1
	test "$CONFIRM" = "y" || _abort "export DOCKER_NAME in shell or ${ARG[1]}"
fi

echo

case ${ARG[2]} in
build)
	echo -e "docker build -t $DOCKER_IMAGE\nYou might need to type in root password\n"
	docker build -t $DOCKER_IMAGE -f "$CONFIG_DIR/$DOCKER_DF" "$CONFIG_DIR"
	;;
run)
	HAS_DOCKER=$(docker ps -a | grep "$DOCKER_NAME\$")
	if test -z "$HAS_DOCKER"; then
		echo "docker run $DOCKER_RUN --name $DOCKER_NAME $DOCKER_IMAGE"
	else
		echo "docker start $DOCKER_NAME"
	fi
	;;
show)
	echo "docker run $DOCKER_RUN --name $DOCKER_NAME $DOCKER_IMAGE"
	;;
start)
	if ! test -z "$STOP_HTTP"; then
		_stop_http
	fi

	HAS_DOCKER=$(docker ps -a | grep "$DOCKER_NAME\$")
	if test -z "$HAS_DOCKER"; then
		echo "docker run $DOCKER_RUN --name $DOCKER_NAME $DOCKER_IMAGE"
		docker run $DOCKER_RUN --name $DOCKER_NAME $DOCKER_IMAGE
	else
		echo "docker start $DOCKER_NAME"
		docker start $DOCKER_NAME
	fi
	;;
stop)
	_docker_stop $DOCKER_NAME
	;;
*)
	_syntax "path/to/config.sh build|start|stop|show|run"
esac

echo

