#!/usr/bin/env bash
# Security notices for the updater: the five newest Arch news items. Prints
# one "tone|text" line per row, for the notice box in update.sh. With --notify
# it sends each alarming one that was not seen before as a notice, once, while
# it is a week old. Style: https://style.ysap.sh/

dir=${BASH_SOURCE[0]%/*}
[[ $dir == "${BASH_SOURCE[0]}" ]] && dir=.
state=${XDG_STATE_HOME:-$HOME/.local/state}/ummitos
seen=$state/notices-seen
cache=$state/news.xml
feed=https://archlinux.org/feeds/news/
notify_days=7
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

# The feed is kept for half an hour, so a few runs in a row do not ask Arch each
# time; an old copy still beats nothing when the network is down.
if [[ -n $(find "$cache" -mmin -30 2> /dev/null) ]]; then
	body=$(< "$cache")
else
	body=$(get "$feed")
	[[ -n $body ]] && mkdir -p "$state" && printf '%s\n' "$body" > "$cache"
fi
[[ -n $body ]] || body=$(cat "$cache" 2> /dev/null)

shown=0
while IFS=$'\t' read -r pub title link; do
	((shown < 5)) || break
	t=$(date -d "$pub" +%s 2> /dev/null) || continue
	title=$(decode "$title")
	tone=mute
	[[ ${title,,} =~ $alarming ]] && tone=warn
	add "$tone" "$link" "$(date -d "$pub" +%F)  $title" '' "$link" "$((now - t))"
	((shown++))
done < <(awk -v RS='</item>' '
	function tag(name,   m) {
		if (!match($0, "<" name ">[^<]*</" name ">"))
			return ""
		m = substr($0, RSTART, RLENGTH)
		return substr(m, length(name) + 3, length(m) - 2 * length(name) - 5)
	}
	# The first record starts with the title of the whole feed; keep from its first item.
	/<item>/ { $0 = substr($0, index($0, "<item>")); print tag("pubDate") "\t" tag("title") "\t" tag("link") }' <<< "$body")

if [[ $1 == --notify ]]; then
	command -v notify-send &> /dev/null || exit 0
	mkdir -p "$state" && touch "$seen" || exit 0
	for i in "${!ids[@]}"; do
		[[ ${tones[i]} == mute ]] && continue
		# Old news is in the updater's box, not worth a notice now.
		((ages[i] > notify_days * 86400)) && continue
		grep -qxF -- "${ids[i]}" "$seen" && continue
		msg=${texts[i]}
		[[ -n ${links[i]} ]] && msg+=$'\n'"<a href=\"${links[i]}\">${links[i]}</a>"
		notify-send -a 'UmmItOS security' -u critical -- "Arch news: ${heads[i]}" "$msg"
		printf '%s\n' "${ids[i]}" >> "$seen"
	done
	exit 0
fi

[[ -n $body ]] || echo 'warn|Could not read the Arch news (offline?)'
for i in "${!ids[@]}"; do
	printf '%s|%s%s\n' "${tones[i]}" "${heads[i]}" "${links[i]:+$'\t'${links[i]}}"
	[[ -n ${texts[i]} ]] || continue
	while IFS= read -r line; do
		printf 'note|%s\n' "$line"
	done < <(fold -s -w 58 <<< "${texts[i]}" | sed 's/ *$//')
done
