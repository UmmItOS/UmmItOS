#!/usr/bin/env bash
# Reads the text out of screenshots into a SQLite table the gallery searches.
# With no arguments it does every new or changed picture under the screenshot
# folder; with files, just those. Style: https://style.ysap.sh/

state=${XDG_STATE_HOME:-$HOME/.local/state}/ummitos
db=$state/ocr.db
conf=${XDG_CONFIG_HOME:-$HOME/.config}/ummitos/screenshot.conf
langs=eng+chi_tra
cjk='[\p{Han}\p{Hiragana}\p{Katakana}]'
jobs=6

sql() {
	sqlite3 -cmd '.timeout 30000' "$db" "$@"
}

folder() {
	local line dir=
	if [[ -f $conf ]]; then
		while IFS= read -r line; do
			[[ $line == folder=* ]] && dir=${line#folder=}
		done < "$conf"
	fi
	echo "${dir:-${HYPRSHOT_DIR:-$HOME/Pictures/Screenshots}}"
}

# One picture: skip it when its time has not changed, else read and store.
index_one() {
	local file=$1 q mtime have tmp
	q=${file//\'/\'\'}
	mtime=$(stat -c %Y -- "$file") || return
	have=$(sql "SELECT mtime FROM shots WHERE path = '$q'")
	[[ $have == "$mtime" ]] && return
	tmp=$(mktemp)
	# Chinese is read with a space between every character; take those out.
	OMP_THREAD_LIMIT=1 nice -n 19 tesseract "$file" stdout -l "$langs" \
		2> /dev/null | tr '\n' ' ' \
		| perl -CSD -pe "s/(?<=$cjk) +(?=$cjk)//g" > "$tmp"
	sql "INSERT OR REPLACE INTO shots (path, mtime, text)
		VALUES ('$q', $mtime, CAST(readfile('$tmp') AS TEXT));"
	rm -f -- "$tmp"
}

# Off in Settings > Anti-forensics: read nothing, and leave no table behind.
if grep -qx 'ocr=0' "${XDG_CONFIG_HOME:-$HOME/.config}/ummitos/privacy.conf" \
	2> /dev/null; then
	exit 0
fi

mkdir -p "$state"
sql 'PRAGMA journal_mode = WAL;' > /dev/null
sql 'CREATE TABLE IF NOT EXISTS shots
	(path TEXT PRIMARY KEY, mtime INTEGER, text TEXT);'
chmod 600 "$db"

if [[ $1 == --one ]]; then
	index_one "$2"
	exit
fi

if (($# > 0)); then
	for f in "$@"; do
		index_one "$f"
	done
	exit
fi

exec 9> "$state/ocr.lock"
flock -n 9 || exit 0

dir=$(folder)
[[ -d $dir ]] || exit 0

# Pictures that are gone drop out of the table.
while IFS= read -r path; do
	[[ -e $path ]] && continue
	q=${path//\'/\'\'}
	sql "DELETE FROM shots WHERE path = '$q'"
done < <(sql 'SELECT path FROM shots')

have=$(mktemp)
want=$(mktemp)
sql "SELECT path || char(9) || mtime FROM shots" | sort > "$have"
find "$dir" -type f \( -iname '*.png' -o -iname '*.jpg' \
	-o -iname '*.jpeg' -o -iname '*.webp' \) -printf '%p\t%Ts\n' \
	| sort > "$want"
comm -13 "$have" "$want" | cut -f1 | tr '\n' '\0' \
	| xargs -0 -r -P "$jobs" -n 1 "$0" --one
rm -f -- "$have" "$want"
