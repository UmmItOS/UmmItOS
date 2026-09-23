#!/usr/bin/env bash
# Run by `wl-paste --watch` on every copy: store it, and have the shell say
# what was copied.
cliphist store
if wl-paste --list-types 2>/dev/null | grep -q '^image/'; then
    qs -c ummitos ipc call copied image
else
    qs -c ummitos ipc call copied text
fi
