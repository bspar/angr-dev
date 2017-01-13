#!/bin/bash

function green
{
	echo "$(tput setaf 6 2>/dev/null)$@$(tput sgr0 2>/dev/null)"
}

function red
{
	echo "$(tput setaf 1 2>/dev/null)$@$(tput sgr0 2>/dev/null)"
}

RED=$(tput setaf 1 2>/dev/null)
GREEN=$(tput setaf 2 2>/dev/null)
NORMAL=$(tput sgr0 2>/dev/null)
center_align() {
	MSG="$1"
	PADDING="$2"
	COLOR="$3"

	[ -z "$PADDING" ] && PADDING="="
	[ -z "$COLOR" ] && COLOR="$GREEN"
	[ -e $(which tput) ] && COL=$(tput cols) || COL=80
	let PAD=\($COL-${#MSG}-2\)/2

	printf "$COLOR"
	printf -- "$PADDING%.0s" $(eval "echo {1..$PAD}")
	printf " %s " "$MSG"
	printf -- "$PADDING%.0s" $(eval "echo {1..$PAD}")
	[ $[$PAD*2 + ${#MSG} + 2] -lt $COL ] && printf "$PADDING"
	printf "$NORMAL"
	printf "\n"
}

function careful_pull
{
	rm -f /tmp/pull-$$
	git pull >> /tmp/pull-$$ 2>> /tmp/pull-$$
	r=$?

	if grep -q "ssh_exchange_identification:" /tmp/pull-$$
	then
		red "Too many concurrent connections to the server. Retrying after sleep."
		sleep $[$RANDOM % 5]
		careful_pull
		return $?
	else
		cat /tmp/pull-$$
		[ $r -eq 0 ] && rm -f /tmp/pull-$$
		return $r
	fi
}

function success
{
	center_align "SUCCESS" "-"
	SUCCESSFUL="$SUCCESSFUL $1"
}

function fail
{
	center_align "FAILURE (return code $2)" "-" "$RED"
	FAILED="$FAILED $1"
}

function do_one
{
	DIR=$1
	shift

	cd $DIR
	center_align "RUNNING ON: $DIR" "#"

	if [ "$1" == "CAREFUL_PULL" ]
	then
		careful_pull && success $DIR || fail $DIR $?
	else
		git "$@" && success $DIR || fail $DIR $?
	fi
	cd ..
}

function do_all
{
	for i in $REPOS
	do
		do_one $i "$@"
	done

	echo ""
	if [ -n "$SUCCESSFUL" ]
	then
		green "# Succeeded:"
		echo $SUCCESSFUL
	fi
	echo ""
	if [ -n "$FAILED" ]
	then
		red "# Failed:"
		echo $FAILED
		[ -n "$EXIT_FAILURE" ] && exit 1
	fi
}

function do_screen
{
	SESSION=git-all-$$
	screen -S $SESSION -d -m sleep 2
	for i in $REPOS
	do
		screen -S $SESSION -X screen -t $i bash -c "REPOS=$i EXIT_FAILURE=1 CONCURRENT=0 ./git_all.sh $@ || bash"
	done
	screen -rd $SESSION

}

[ -z "$REPOS" ] && REPOS=$(ls -d */.git | sed -e "s/\/\.git//")

if [ "$CONCURRENT" == "1" ]
then
	do_screen "$@"
else
	do_all "$@"
fi
