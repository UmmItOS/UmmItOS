#!/usr/bin/env bash
# Overwrites, then deletes, the traces the desktop keeps about you, so they
# cannot be read back from the files. Usage:
#   wipe-traces.sh [--passes N] ocr clipboard changes launches place temp
# Prints one "wiped<TAB>name<TAB>files" line per name. With --list it wipes
# nothing and prints "file<TAB>name<TAB>path<TAB>bytes" for each file it would,
# and "fs<TAB>type" for the file system they sit on.
# Style: https://style.ysap.sh/

passes=3
mode=wipe
current=
state=${XDG_STATE_HOME:-$HOME/.local/state}
cache=${XDG_CACHE_HOME:-$HOME/.cache}
run=${XDG_RUNTIME_DIR:-/tmp}
wiped=0

# Overwrite with random data N times, once with zeros, then unlink.
shred_file() {
	[[ -f $1 || -L $1 ]] || return
	if [[ $mode == list ]]; then
		printf 'file\t%s\t%s\t' "$current" "$1"
		stat -c %s -- "$1"
		return
	fi
	if shred -f -n "$passes" -z -u -- "$1" 2> /dev/null; then
		((wiped++))
	fi
}

# Every file under a path, then the folders it leaves empty.
shred_tree() {
	local f
	[[ -e $1 ]] || return
	if [[ -d $1 ]]; then
		while IFS= read -r -d '' f; do
			shred_file "$f"
		done < <(find "$1" -type f -print0)
		if [[ $mode == wipe ]]; then
			find "$1" -depth -type d -empty -delete 2> /dev/null
		fi
	else
		shred_file "$1"
	fi
}

# Every file called NAME anywhere under the shell's per-instance folders.
shred_named() {
	local f
	while IFS= read -r -d '' f; do
		shred_file "$f"
	done < <(find "$state/quickshell" -type f -name "$1" -print0 \
		2> /dev/null)
}

wipe_ocr() {
	if [[ $mode == wipe ]]; then
		pkill -x tesseract
		pkill -f ocr-index.sh
		sleep 0.3
	fi
	for f in ocr.db ocr.db-wal ocr.db-shm ocr.lock; do
		shred_tree "$state/ummitos/$f"
	done
}

wipe_clipboard() {
	[[ $mode == wipe ]] && wl-copy --clear 2> /dev/null
	shred_tree "$cache/cliphist"
	shred_tree "$state/ummitos/clipboard-expiry"
	shred_tree "$state/ummitos/clipboard.log"
	while IFS= read -r -d '' d; do
		shred_tree "$d"
	done < <(find "$cache/quickshell" -type d -name clipboard -print0 \
		2> /dev/null)
}

wipe_changes() {
	shred_named file-changes.json
}

wipe_launches() {
	shred_named launches.json
}

wipe_place() {
	shred_named weather-location.txt
}

wipe_temp() {
	local f
	while IFS= read -r -d '' f; do
		shred_tree "$f"
	done < <(find "$run" -maxdepth 1 -name 'ummitos-*' -print0 2> /dev/null)
}

names=()
while (($# > 0)); do
	case $1 in
		--passes)
			passes=$2
			shift
			;;
		--list) mode=list ;;
		*) names+=("$1") ;;
	esac
	shift
done
[[ $passes =~ ^[0-9]+$ ]] && ((passes >= 1)) || passes=3

[[ $mode == list ]] && printf 'fs\t%s\n' "$(stat -f -c %T -- "$state")"

for name in "${names[@]}"; do
	wiped=0
	current=$name
	case $name in
		ocr | clipboard | changes | launches | place | temp)
			"wipe_$name"
			;;
		*) continue ;;
	esac
	[[ $mode == wipe ]] && printf 'wiped\t%s\t%d\n' "$name" "$wiped"
done

[[ $mode == wipe ]] && sync
