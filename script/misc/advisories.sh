#!/usr/bin/env bash
# Security notices for the updater: UmmItOS's own advisories (advisories.json)
# and the Arch news of the last 30 days. Prints one "tone|text" line per row,
# for the notice box in update.sh. With --notify it sends each alarming one that
# was not seen before as a notice, once (news only while it is a week old). Offline, it falls back to the
# advisories file next to it. Style: https://style.ysap.sh/

dir=${BASH_SOURCE[0]%/*}
[[ $dir == "${BASH_SOURCE[0]}" ]] && dir=.
state=${XDG_STATE_HOME:-$HOME/.local/state}/ummitos
seen=$state/notices-seen
feed=https://archlinux.org/feeds/news/
own=https://raw.githubusercontent.com/UmmItOS/UmmItOS/master/script/misc/advisories.json
news_days=30
notify_days=7
own_days=60
alarming='malicious|malware|compromis|rootkit|security|manual intervention'

tones=()
ids=()
heads=()
texts=()
links=()
ages=()

get() { curl -fsSL --connect-timeout 3 -m 6 "$1" 2> /dev/null; }

# add TONE ID HEAD TEXT LINK AGE. What arrives from the network goes to a terminal
# and a notice, so control characters go and only https links stay.
add() {
	local link=$5
	[[ $link =~ ^https://[[:graph:]]+$ ]] || link=
	tones+=("$1")
	ids+=("${2//[[:cntrl:]]/}")
	heads+=("${3//[[:cntrl:]]/}")
	texts+=("${4//[[:cntrl:]]/}")
	links+=("$link")
	ages+=("$6")
}

decode() {
	local s=$1
	s=${s//&lt;/<}
	s=${s//&gt;/>}
	s=${s//&quot;/\"}
	s=${s//&#x27;/\'}
	s=${s//&#39;/\'}
	printf '%s' "${s//&amp;/&}"
}

now=$(date +%s)

json=$(get "$own")
jq -e 'type == "array"' <<< "$json" &> /dev/null || json=$(cat "$dir/advisories.json" 2> /dev/null)
while IFS=$'\t' read -r id date title text link; do
	[[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || continue
	t=$(date -d "$date" +%s 2> /dev/null) || continue
	((now - t <= own_days * 86400)) || continue
	add bad "$id" "$date  $title" "$text" "$link" "$((now - t))"
done < <(jq -r '.[]? | [.id, .date, .title, .text, .link] | @tsv' <<< "$json" 2> /dev/null)

shown=0
while IFS=$'\t' read -r pub title link; do
	((shown < 3)) || break
	t=$(date -d "$pub" +%s 2> /dev/null) || continue
	((now - t <= news_days * 86400)) || continue
	title=$(decode "$title")
	tone=mute
	[[ ${title,,} =~ $alarming ]] && tone=warn
	add "$tone" "$link" "$(date -d "$pub" +%F)  Arch news: $title" '' "$link" "$((now - t))"
	((shown++))
done < <(get "$feed" | awk -v RS='</item>' '
	function tag(name,   m) {
		if (!match($0, "<" name ">[^<]*</" name ">"))
			return ""
		m = substr($0, RSTART, RLENGTH)
		return substr(m, length(name) + 3, length(m) - 2 * length(name) - 5)
	}
	# The first record starts with the title of the whole feed; keep from its first item.
	/<item>/ { $0 = substr($0, index($0, "<item>")); print tag("pubDate") "\t" tag("title") "\t" tag("link") }')

if [[ $1 == --notify ]]; then
	command -v notify-send &> /dev/null || exit 0
	mkdir -p "$state" && touch "$seen" || exit 0
	for i in "${!ids[@]}"; do
		[[ ${tones[i]} == mute ]] && continue
		# Old news is in the updater's box, not worth a notice now.
		[[ ${tones[i]} == warn ]] && ((ages[i] > notify_days * 86400)) && continue
		grep -qxF -- "${ids[i]}" "$seen" && continue
		body=${texts[i]}
		[[ -n ${links[i]} ]] && body+=$'\n'"<a href=\"${links[i]}\">${links[i]}</a>"
		notify-send -a 'UmmItOS security' -u critical -- "${heads[i]}" "$body"
		printf '%s\n' "${ids[i]}" >> "$seen"
	done
	exit 0
fi

for i in "${!ids[@]}"; do
	printf '%s|%s\n' "${tones[i]}" "${heads[i]}"
	[[ -n ${texts[i]} ]] || continue
	while IFS= read -r line; do
		printf 'note|%s\n' "$line"
	done < <(fold -s -w 58 <<< "${texts[i]}" | sed 's/ *$//')
done
