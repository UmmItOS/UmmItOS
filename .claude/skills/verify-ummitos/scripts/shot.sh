#!/usr/bin/env bash
# shot.sh <name>: screenshot the nested output into the run's evidence folder; prints the path.
source "$(dirname "$0")/env.sh"
out=$EVIDENCE/$(date +%H%M%S)-${1:-shot}.png
# Bounded: grim waits for a frame, and a stack without its headless output never sends one.
in_stack timeout 10 grim -o VERIFY "$out" && echo "$out"
