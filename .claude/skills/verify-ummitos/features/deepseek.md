# DeepSeek balance card

## What it is

A card in the desktop widget column (top right, under the weather card) with the DeepSeek account balance. It is off until the desktop right-click menu's "DeepSeek balance" switch is turned on, and it needs the API key in `~/.config/ummitos/deepseek.key`.

## Sub-features

- `ds-switch`: the "DeepSeek balance" row of the right-click menu flips `deepseek=` in `desktop.conf` between `0` (the default) and `1`.
- `ds-nokey`: with the switch on and no key file, the card shows "DeepSeek" and "Put your API key in ~/.config/ummitos/deepseek.key".
- `ds-ok`: with a key and a good answer, the card shows the total ("¥110.00") and "Granted 10.00 · Topped up 100.00".
- `ds-low`: when the service says `is_available` is false, the amount stays and "Balance too low for API calls" shows under it.
- `ds-refused`: when the service refuses (a wrong key), the last balance stays and "Can't read the balance. Check the key." shows.
- `ds-off`: switching it off fades the card away.
- `ds-key-private`: curl gets the key on stdin as a config line, never in its arguments.

## How to get to it (user POV)

- Right-click the empty desktop, then the "DeepSeek balance" switch. Put the key in `~/.config/ummitos/deepseek.key`. `qs -c ummitos ipc call deepseek refresh` reads again at once.

## Driving it with verify-ummitos

The stack has no real key and must never get one. Start it with a stub `curl` first on `PATH`; it answers only the balance URL and hands every other call to the real `curl`:

```sh
S=/tmp/vu-deepseek; mkdir -p $S/bin; echo ok > $S/mode
cat > $S/bin/curl <<EOF
#!/usr/bin/env bash
case "\$*" in *api.deepseek.com/user/balance*) ;; *) exec /usr/bin/curl "\$@";; esac
{ echo "ARGV: \$*"; echo "STDIN:"; cat; } > $S/last-call.txt
case "\$(cat $S/mode)" in
  ok)  echo '{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"110.00","granted_balance":"10.00","topped_up_balance":"100.00"}]}' ;;
  low) echo '{"is_available":false,"balance_infos":[{"currency":"CNY","total_balance":"0.00","granted_balance":"0.00","topped_up_balance":"0.00"}]}' ;;
  401) exit 22 ;;
esac
EOF
chmod +x $S/bin/curl
PATH=$S/bin:$PATH .claude/skills/verify-ummitos/scripts/up.sh
```

Steps (proven 2026-11-27):

- **Switch.** Park the pointer, right-click the desktop (`run.sh wlrctl pointer click right`), press `run.sh wtype -k Down` six times (the focus bar sits on "DeepSeek balance"), then `run.sh wtype -k space`. `grep deepseek $STACK/home/.config/ummitos/desktop.conf` shows `deepseek=1` and the menu stays open; Escape closes it.
- **No key.** Within about 2 s the card shows the key path hint (`shot.sh ds-nokey`).
- **Good answer.** Write a test key (`printf 'sk-TEST\n' > $STACK/home/.config/ummitos/deepseek.key`, then `chmod 600` it), run `ipc.sh deepseek refresh` and wait 2.5 s: "¥110.00" and the granted and topped-up line.
- **Key private.** `cat $S/last-call.txt`: the `ARGV` line has no key, and `STDIN` holds `header = "Authorization: Bearer sk-TEST"`.
- **Too low, refused.** `echo low > $S/mode`, then `ipc.sh deepseek refresh`; then `echo 401 > $S/mode` and refresh again: the last balance stays and the note changes.
- **Off.** Repeat the switch steps; the card fades away and `desktop.conf` has `deepseek=0`.

## Gotchas

- The start-up health-check toast sits top right and pushes the column down, so crop below it when reading a screenshot.
- Five Down presses land on "Now playing card", not on the new row.
- Never put a real key in the stack: the fake HOME is deleted by `down.sh`, but the request would still leave the machine.
