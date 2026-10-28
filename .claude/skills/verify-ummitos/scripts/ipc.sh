#!/usr/bin/env bash
# ipc.sh <target> <function> [args...]: call the test shell's IPC (never the live one).
source "$(dirname "$0")/env.sh"
in_stack qs -c "$CONFIG_ID" ipc call "$@"
