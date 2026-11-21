#!/usr/bin/env bash

locked() {
	[[ $(qs -c ummitos ipc call lock isLocked 2> /dev/null) == true ]]
}

lock_and_wait() {
	local i
	qs -c ummitos ipc call lock lock > /dev/null 2>&1
	for ((i = 0; i < 30; i++)); do
		locked && return 0
		sleep 0.1
	done
	return 1
}

locked && exit 0
lock_and_wait && exit 0

# Only when no shell runs: one that is reloading answers "Not ready" for a moment.
if ! qs list -c ummitos 2> /dev/null | grep -q '^Instance'; then
	qs -c ummitos -d > /dev/null 2>&1
	for ((i = 0; i < 50; i++)); do
		qs -c ummitos ipc show 2> /dev/null | grep -q '^target lock' && break
		sleep 0.1
	done
fi
lock_and_wait && exit 0

notify-send -a Lock -u critical "Could not lock the screen" \
	"The shell did not answer. Restart it with: qs -c ummitos -d"
exit 1
