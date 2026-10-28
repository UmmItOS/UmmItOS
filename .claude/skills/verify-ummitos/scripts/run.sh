#!/usr/bin/env bash
# run.sh <command...>: run any command inside the test stack (notify-send, wtype, hyprctl, playerctl...).
source "$(dirname "$0")/env.sh"
in_stack "$@"
