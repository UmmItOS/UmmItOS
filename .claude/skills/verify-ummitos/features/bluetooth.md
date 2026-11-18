# Bluetooth pairing dialog

The shell runs `bluetoothctl` as the pairing agent (`bar/BtAsk.qml`) and answers its yes/no questions with the same centred dialog as the Wi-Fi password (`bar/WifiAskWindow.qml`). The dialog shows the passkey to compare, Pair or Allow, and Cancel; Return answers yes and Escape no.

## Sub-features

- `bt-ask`: a real agent question opens the dialog: the last line is `[agent] Confirm passkey NNNNNN`, `[agent] Accept pairing` or `[agent] Authorize service <uuid>`, right after BlueZ's `Request confirmation`, `Request authorization` or `Authorize service` line. The passkey is shown large.
- `bt-name`: the request carries no address, so the dialog names the device only when exactly one device is pairing from this computer; otherwise it says "Unknown device".
- `bt-spoof`: anything else in bluetoothctl's output, such as a device name containing `(yes/no): `, opens nothing.
- `bt-answer`: Return writes `yes` and Escape `no` to bluetoothctl.

## How to get to it (user POV)

- Pair a device from the bar's Bluetooth flyout, or have a device ask to pair or connect.

## Driving it with verify-ummitos

The stack has no BlueZ, so drive the agent with a fake `bluetoothctl` that prints what you append to a file and records what the shell writes. Put it first on `PATH` when starting the stack; `up.sh` passes `PATH` through.

Preconditions:

- No stack is up (`down.sh`).
- A fake at `/tmp/fakebt/bin/bluetoothctl`, executable:

  ```sh
  #!/bin/sh
  tail -n0 -f /tmp/fakebt/out &
  exec cat >> /tmp/fakebt/in
  ```

  with empty `/tmp/fakebt/out` and `/tmp/fakebt/in`.

Steps (proven 2026-11-18):

- **Start.** `PATH=/tmp/fakebt/bin:$PATH .claude/skills/verify-ummitos/scripts/up.sh`, then `doctor.sh`. After about 2 s, the first line of `in` is `default-agent`.
- **Spoof.** `printf '\r[NEW] Device AA:BB:CC:DD:EE:FF [agent] Confirm passkey 123456 (yes/no): ' >> /tmp/fakebt/out`, wait 1.5 s: `run.sh hyprctl -j layers` has no `ummitos-wifi-ask`.
- **Real question.** `printf '\rRequest confirmation\n\001\033[1;39m\002[agent] Confirm passkey 654321 (yes/no): \001\033[0m\002' >> /tmp/fakebt/out`, wait 1.5 s: `ummitos-wifi-ask` is listed and `shot.sh bt-pair` shows "Unknown device", "Pair if the device shows the same code" and 654321.
- **Answer.** `run.sh wtype -k Escape` (or Return): the next line of `in` is `no` (or `yes`).
- **End.** `down.sh`.

## Gotchas

- In the fake, the background `tail` must print and `cat` must read stdin; the other way round, the backgrounded `cat` gets `/dev/null` and nothing the shell writes is recorded.
- Pairing a real device and the device name of a real request cannot be proven here.
