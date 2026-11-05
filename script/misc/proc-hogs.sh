#!/bin/sh
# One shot: prints "pid<TAB>cpu<TAB>gpu<TAB>name" (at most 5) for processes using >= 15% of the
# machine's CPU or >= 30% of the GPU (amdgpu gfx engine) over a 1 s window. Read-only, never kills.

# Per pid: "c pid jiffies" and "g pid ns". The comm in stat can hold spaces and ')', so cut at the last ')'.
sample() {
    awk '
        FILENAME ~ /\/stat$/ {
            split(FILENAME, p, "/"); s = $0; sub(/.*\) /, "", s); split(s, f, " ")
            print "c", p[3], f[12] + f[13]; nextfile
        }
        /^drm-client-id:/ { id = $2 }
        /^drm-engine-gfx:/ {
            split(FILENAME, p, "/")
            if (!((p[3], id) in seen)) { seen[p[3], id] = 1; print "g", p[3], $2 }
        }
        FNR == 1 { id = "" }
    ' /proc/[0-9]*/stat /proc/[0-9]*/fdinfo/* 2>/dev/null
}

t0=$(date +%s%N)
a=$(sample)
sleep 1
b=$(sample)
t1=$(date +%s%N)

printf '%s\n--\n%s\n' "$a" "$b" | awk -v ns="$((t1 - t0))" -v cpus="$(nproc)" -v hz="$(getconf CLK_TCK)" '
    $1 == "--" { second = 1; next }
    # A process can hold several GPU clients, so their times add up; one seen only in the second read is skipped.
    !second { v[$1, $2] += $3; next }
    ($1, $2) in v { d[$1, $2] += $3; ids[$2] = 1 }
    END {
        for (pid in ids) {
            d["c", pid] -= v["c", pid]; d["g", pid] -= v["g", pid]
            cpu = d["c", pid] * 100 / (ns / 1e9 * hz * cpus)
            gpu = d["g", pid] * 100 / ns
            if (gpu > 100) gpu = 100
            if (cpu < 0) cpu = 0
            if (gpu < 0) gpu = 0
            if (cpu < 15 && gpu < 30) continue
            name = "?"; f = "/proc/" pid "/comm"; getline name < f; close(f)
            printf "%s\t%.0f\t%.0f\t%s\t%.2f\n", pid, cpu, gpu, name, (cpu > gpu ? cpu : gpu)
        }
    }
' | sort -t "$(printf '\t')" -k5,5nr | grep -v "$(printf '\t')Hyprland$(printf '\t')" | head -n 5 | cut -f1-4
