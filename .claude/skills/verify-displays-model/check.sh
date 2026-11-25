#!/usr/bin/env bash
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
spec=${1:-$here/DisplaysModel.tla}
version=v1.8.0
sum=fdffef247f563ef6edbfd44958d2a82db79e7564e07cb673262d896353fa6713  # GitHub's own digest for the v1.8.0 asset on 2026-11-25; the tag is a rolling prerelease, so a new upload means a new hash: compare with `gh api repos/tlaplus/tlaplus/releases/tags/v1.8.0` before changing it
jar=${XDG_CACHE_HOME:-$HOME/.cache}/ummitos-tla/tla2tools-$version.jar
properties=(NeverStranded SnapshotIsHome)

command -v java > /dev/null || { echo "check.sh: java is not installed (paru -S jre-openjdk-headless)" >&2; exit 2; }
if [[ ! -f $jar ]]; then
	mkdir -p "${jar%/*}"
	curl -fsSL -o "$jar.part" "https://github.com/tlaplus/tlaplus/releases/download/$version/tla2tools.jar" || { echo "check.sh: download failed" >&2; exit 2; }
	mv "$jar.part" "$jar"
fi
if [[ $(sha256sum "$jar" | cut -d' ' -f1) != "$sum" ]]; then
	echo "check.sh: $jar does not match the pinned sha256; delete it and rerun" >&2
	exit 2
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$spec" "$work/DisplaysModel.tla"
traces=${TMPDIR:-/tmp}/verify-displays-model
mkdir -p "$traces"
new=0

for scope in childlives childdies; do
	[[ $scope == childlives ]] && survives=TRUE || survives=FALSE
	for prop in "${properties[@]}"; do
		printf 'CONSTANTS ChildSurvives = %s Seconds = 2 MaxApplies = 2\nSPECIFICATION Spec\nINVARIANT TypeOK\nINVARIANT %s\n' "$survives" "$prop" > "$work/DisplaysModel.cfg"
		# One worker: the counterexample is then the same on every run.
		out=$(cd "$work" && java -XX:+UseParallelGC -cp "$jar" tlc2.TLC -workers 1 -deadlock -cleanup DisplaysModel 2>&1)
		rc=$?
		if ((rc == 0)); then
			printf '  %-10s %-26s holds\n' "$scope" "$prop"
			continue
		fi
		steps=$(grep -E '^State [0-9]+:|^Back to state' <<< "$out" | sed -E 's/^Back to state [0-9]+: <([A-Za-z0-9]+).*/back-to-\1/; s/^State [0-9]+: <([A-Za-z0-9]+).*/\1/; s/^State [0-9]+: Stuttering.*/stutter/' | grep -v '^Initial$' | tr '\n' ' ' | sed 's/ $//')
		if [[ -z $steps ]]; then
			printf '  %-10s %-26s TLC ERROR (exit %d)\n' "$scope" "$prop" "$rc"
			printf '%s\n' "$out" | tail -20
			new=1
			continue
		fi
		trace=$traces/$scope-$prop.trace
		printf '%s\n' "$out" | sed -n '/^Error:/,/states generated/p' > "$trace"
		known=
		while IFS= read -r line; do
			want=${line#"$scope $prop: "}
			[[ $want == "$line" ]] && continue
			[[ "$steps " == "${want%%  #*} "* ]] && known=${line##*# } && break
		done < "$here/known-findings.txt"
		if [[ -n $known ]]; then
			printf '  %-10s %-26s known finding %s\n' "$scope" "$prop" "${known%% *}"
		else
			printf '  %-10s %-26s NEW VIOLATION: %s\n' "$scope" "$prop" "$steps"
			printf '  %-10s %-26s trace: %s\n' '' '' "$trace"
			new=1
		fi
	done
done

if ((new)); then
	echo "check.sh: new violation; replay it against Displays.qml (SKILL.md, Reading a result)"
	exit 1
fi
echo "check.sh: no new violations"
exit 0
