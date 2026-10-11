#!/usr/bin/env bash
# One battery sample, run by the shell every minute, plugged in or not: the
# battery's energy and draw, each program's CPU time since the last sample,
# brightness, Wi-Fi, Bluetooth and power profile, into a SQLite table the
# battery screen reads. A long gap with a drop in energy is a sleep.
# Style: https://style.ysap.sh/

state=${XDG_STATE_HOME:-$HOME/.local/state}/ummitos
db=$state/battery.db
prev=${XDG_RUNTIME_DIR:-/tmp}/ummitos-battery
# Longer than this between samples means the machine slept.
sleep_gap=180

sql() {
	sqlite3 -cmd '.timeout 10000' "$db" "$@"
}

# The first battery and whether any mains supply is online.
bat=
plugged=0
for d in /sys/class/power_supply/*; do
	type=$(< "$d/type")
	if [[ $type == Battery && -z $bat ]]; then
		bat=$d
	elif [[ $type == Mains && $(< "$d/online") == 1 ]]; then
		plugged=1
	fi
done
[[ -n $bat && -r $bat/energy_now ]] || exit 0

now=$(date +%s)
energy=$(awk '{ printf "%.4f", $1 / 1e6 }' "$bat/energy_now")
watts=$(awk '{ printf "%.3f", $1 / 1e6 }' "$bat/power_now" 2> /dev/null)
[[ $(< "$bat/status") == Charging ]] && watts=-$watts

brightness=
for b in /sys/class/backlight/*; do
	[[ -r $b/brightness ]] || continue
	brightness=$(awk -v m="$(< "$b/max_brightness")" '{ printf "%.1f", $1 * 100 / m }' "$b/brightness")
	break
done

# On when the radio is not blocked, soft or hard.
radio() {
	local r on=0
	for r in /sys/class/rfkill/rfkill*; do
		[[ $(< "$r/type") == "$1" ]] || continue
		[[ $(< "$r/soft") == 0 && $(< "$r/hard") == 0 ]] && on=1
	done
	echo "$on"
}
wifi=$(radio wlan)
bt=$(radio bluetooth)
profile=$(cat /sys/firmware/acpi/platform_profile 2> /dev/null) || profile=unknown

mkdir -p "$state" && chmod 700 "$state"
sql 'CREATE TABLE IF NOT EXISTS samples (t INTEGER PRIMARY KEY, plugged INTEGER,
	energy_wh REAL, watts REAL, cpu REAL, brightness REAL, wifi INTEGER, bt INTEGER, profile TEXT);
CREATE TABLE IF NOT EXISTS usage (t INTEGER, app TEXT, cpu_s REAL);
CREATE INDEX IF NOT EXISTS usage_t ON usage (t);
CREATE TABLE IF NOT EXISTS sleeps (start INTEGER, end INTEGER, wh REAL);'
chmod 600 "$db"

# Each process's CPU ticks now, as "pid<TAB>app<TAB>ticks". The app is the program file, so a
# browser's many tab processes count as one; without one (kernel threads) it is the process name,
# which sits in brackets and may hold spaces, so the fields are counted after the last ")".
exes=$(find /proc -mindepth 2 -maxdepth 2 -name exe -printf '%h\t%l\n' 2> /dev/null)
snapshot=$(awk -v exes="$exes" 'BEGIN {
	n = split(exes, lines, "\n")
	for (i = 1; i <= n; i++) { split(lines[i], kv, "\t"); sub(/^\/proc\//, "", kv[1]); sub(/.*\//, "", kv[2]); sub(/ \(deleted\)$/, "", kv[2]); exe[kv[1]] = kv[2] }
}
{
	line = $0; open = index(line, "("); shut = 0
	for (i = length(line); i > 0; i--) if (substr(line, i, 1) == ")") { shut = i; break }
	name = substr(line, open + 1, shut - open - 1)
	split(substr(line, shut + 2), f, " ")
	split(FILENAME, p, "/")
	if (exe[p[3]] != "") name = exe[p[3]]
	else if (name ~ /^(kworker|ksoftirqd|irq\/|rcu_|migration|idle_inject|kthreadd)/) name = "kernel"
	printf "%s\t%s\t%d\n", p[3], name, f[12] + f[13]
}' /proc/[0-9]*/stat 2> /dev/null)

# Usage needs the last sample to diff against; the first run only sets it.
if [[ -r $prev.ticks && -r $prev.last ]]; then
	read -r last_t last_energy < "$prev.last"
	gap=$((now - last_t))
	hz=$(getconf CLK_TCK)
	cores=$(nproc)
	rows=$(awk -F '\t' -v hz="$hz" -v t="$now" '
		NR == FNR { before[$1] = $3; next }
		{ d = $3 - ($1 in before ? before[$1] : 0); if (d > 0) used[$2] += d / hz }
		END { for (a in used) if (used[a] >= 0.05) {
			gsub(/\047/, "\047\047", a); printf "INSERT INTO usage VALUES (%d, \047%s\047, %.2f);\n", t, a, used[a] } }
	' "$prev.ticks" - <<< "$snapshot")
	cpu=$(awk -v g="$gap" -v c="$cores" -v hz="$hz" -F '\t' '
		NR == FNR { before[$1] = $3; next }
		{ d = $3 - ($1 in before ? before[$1] : 0); if (d > 0) s += d / hz }
		END { if (g > 0) printf "%.4f", s / (g * c) }
	' "$prev.ticks" - <<< "$snapshot")
	slept=
	if ((gap > sleep_gap)) && awk -v a="$last_energy" -v b="$energy" 'BEGIN { exit !(a > b) }'; then
		slept="INSERT INTO sleeps VALUES ($last_t, $now, $(awk -v a="$last_energy" -v b="$energy" 'BEGIN { printf "%.4f", a - b }'));"
	fi
	sql "BEGIN; INSERT OR REPLACE INTO samples VALUES ($now, $plugged, $energy, ${watts:-NULL},
		${cpu:-NULL}, ${brightness:-NULL}, $wifi, $bt, '${profile//\'/}'); $rows $slept COMMIT;"
fi

printf '%s\n' "$snapshot" > "$prev.ticks"
echo "$now $energy" > "$prev.last"
