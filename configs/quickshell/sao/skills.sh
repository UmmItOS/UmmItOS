#!/bin/sh
# The agent skills Claude Code can use here, one per line: how to call it, a tab, what it does.
# Your own first (~/.claude/skills), then plugins' (plugin:skill); a name seen twice is listed once.

emit() {
    awk -v pre="$2" '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        /^name:/ { sub(/^name:[ ]*/, ""); gsub(/"/, ""); name = $0 }
        /^description:/ {
            sub(/^description:[ ]*/, ""); desc = $0
            # A folded description starts on the next line.
            if (desc == ">" || desc == "|" || desc == ">-" || desc == "") { getline; sub(/^[ ]+/, ""); desc = $0 }
            gsub(/^"|"$/, "", desc)
        }
        END { if (name != "") printf "%s%s\t%s\n", pre, name, desc }
    ' "$1"
}

{
    for f in "$HOME"/.claude/skills/*/SKILL.md; do
        [ -f "$f" ] && emit "$f" ""
    done
    find "$HOME/.claude/plugins/cache" -path '*/skills/*' -name SKILL.md -not -path '*/deprecated/*' 2>/dev/null | sort |
        while read -r f; do
            plugin=${f#"$HOME"/.claude/plugins/cache/*/}
            emit "$f" "${plugin%%/*}:"
        done
} | awk -F '\t' '!seen[$1]++'
