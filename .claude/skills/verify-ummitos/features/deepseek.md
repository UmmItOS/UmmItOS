# DeepSeek balance card

## What it is

A card in the desktop widget column (top right, under the weather card) with the DeepSeek account balance. It is off until its switch is turned on, in the desktop right-click menu or on Settings → Misc. The key is pasted on Settings → Misc, and the same page picks CNY or USD.

## Sub-features

- `ds-switch`: the "DeepSeek balance" row of the right-click menu, or the same row on Settings → Misc, flips `deepseek=` in `desktop.conf` between `0` (the default) and `1`.
- `ds-nokey`: with the switch on and no key file, the card shows "DeepSeek" and "Add your DeepSeek API key in Settings, Misc."
- `ds-bad-key`: a pasted key with anything but letters, digits, `.`, `_` or `-` (or under 8 characters) is refused: the hint turns red, "That does not look like a key.", and no file is written.
- `ds-key-save`: a good key plus Enter writes `deepseek.key` with mode `600`, clears the field (it never shows a saved key), changes the hint to "A key is saved…" and shows "Remove the key".
- `ds-ok`: with a key and a good answer, the card shows the total ("¥110.00") and "Granted 10.00 · Topped up 100.00".
- `ds-interval`: the "Read the balance every" row (15 s, 30 s, 1 min, 5 min, 10 min; saved as `deepseeksec=`, 60 s by default) sets how often the card reads the balance while it shows.
- `ds-usd`: picking "USD $" on the Balance currency row (saved as `deepseekcur=USD`) shows the account's USD entry ("$15.50") without a new request.
- `ds-no-usd`: when the account has no entry in the chosen currency, the card shows the other one and "No USD balance on this account."; nothing is converted.
- `ds-low`: when the service says `is_available` is false, the amount stays and "Balance too low for API calls" shows under it.
- `ds-refused`: when the service refuses (a wrong key), the last balance stays and "Can't read the balance. Check the key." shows.
- `ds-remove`: "Remove the key" deletes the file, and the card goes back to the "Add your key" hint with no old amount.
- `ds-off`: switching it off fades the card away.
- `ds-key-private`: curl gets the key on stdin as a config line, never in its arguments, and no process's command line holds it.

## How to get to it (user POV)

- Settings (the gear beside the power button) → Misc: turn on "DeepSeek balance", paste the key, press Enter, pick the currency. `qs -c ummitos ipc call deepseek refresh` reads again at once.

## Driving it with verify-ummitos

The stack has no real key and must never get one. Start it with a stub `curl` first on `PATH`; it answers only the balance URL and hands every other call to the real `curl`. Mode `both` returns a CNY and a USD entry, `ok` only CNY, `401` a refusal:

```sh
S=/tmp/vu-deepseek; mkdir -p $S/bin; echo both > $S/mode
cat > $S/bin/curl <<EOF
#!/usr/bin/env bash
case "\$*" in *api.deepseek.com/user/balance*) ;; *) exec /usr/bin/curl "\$@";; esac
date +%s.%N >> $S/calls.log; { echo "ARGV: \$*"; echo "STDIN:"; cat; } > $S/last-call.txt
case "\$(cat $S/mode)" in
  ok)   echo '{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"110.00","granted_balance":"10.00","topped_up_balance":"100.00"}]}' ;;
  both) echo '{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"110.00","granted_balance":"10.00","topped_up_balance":"100.00"},{"currency":"USD","total_balance":"15.50","granted_balance":"0.50","topped_up_balance":"15.00"}]}' ;;
  low)  echo '{"is_available":false,"balance_infos":[{"currency":"CNY","total_balance":"0.00","granted_balance":"0.00","topped_up_balance":"0.00"}]}' ;;
  401)  exit 22 ;;
esac
EOF
chmod +x $S/bin/curl
PATH=$S/bin:$PATH .claude/skills/verify-ummitos/scripts/up.sh
```

Steps (proven 2026-11-27, at 1920×1080):

`C` is the stack's own config folder: `C=$(.claude/skills/verify-ummitos/scripts/run.sh sh -c 'echo "$HOME"')/.config/ummitos`.

- **Open the page.** `ipc.sh settings toggle`, then `ipc.sh settings page 10` (Misc). Click with `hyprctl dispatch 'hl.dsp.cursor.move({ x = X, y = Y })'` and `run.sh wlrctl pointer click left`. Positions: the card switch (893, 367), the key field (755, 431), "Remove the key" (850, 488, only with a key saved). With no key saved, "15 s" is at (628, 487) and USD at (835, 552); a saved key adds the Remove row, so they move to (628, 537) and (835, 602).
- **Switch and no key.** Click the switch: `grep deepseek $C/desktop.conf` shows `deepseek=1`, and within about 2 s the card shows the hint (`shot.sh`).
- **Bad key.** Click the key field, `run.sh wtype 'bad"key-12345'`, `run.sh wtype -k Return`: the red hint shows and `$C/deepseek.key` does not exist.
- **Good key.** `run.sh wtype -M ctrl a -m ctrl`, `-k BackSpace`, `run.sh wtype 'sk-TESTKEY-1234567890'`, `-k Return`, wait 3.5 s. `stat -c %a` on the file says `600` and it holds that line. The card shows "¥110.00".
- **USD.** Click USD: `desktop.conf` has `deepseekcur=USD` and the card shows "$15.50".
- **No USD entry.** `echo ok > $S/mode`, `ipc.sh deepseek refresh`, wait 3 s: "¥110.00" and the note.
- **Interval** (proven 2026-11-27). Click "15 s", empty `$S/calls.log`, wait 50 s: `desktop.conf` has `deepseeksec=15` and the log holds 3 reads 15.0 s apart.
- **Key private.** In `$S/last-call.txt` the `ARGV` line has no key and `STDIN` holds `header = "Authorization: Bearer sk-TESTKEY-1234567890"`; `grep -l TESTKEY /proc/[0-9]*/cmdline` finds nothing.
- **Remove.** Click "Remove the key": the file is gone and the card shows the hint with no amount.

## Gotchas

- The start-up health-check toast sits top right and pushes the column down, so crop below it when reading a screenshot.
- In the right-click menu, five Down presses land on "Now playing card", not on the DeepSeek row; it takes six.
- `desktop.conf` is read once at start and the stack does not reload on `touch`, so set the switch through the UI, not by writing the file.
- Never put a real key in the stack: the fake HOME is deleted by `down.sh`, but the request would still leave the machine.
