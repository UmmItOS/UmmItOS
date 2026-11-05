# Heavy process warning

When one process keeps the CPU or GPU busy, the bar shows a warning beside the file-change label, in the warning colour: "⚠ ffmpeg CPU 65%". It shows only on the bar, never as a desktop notice, and it fades once the load drops. It only warns and never kills anything.

## Sub-features

- `hog-sampler`: `script/misc/proc-hogs.sh` prints `pid<TAB>cpu<TAB>gpu<TAB>name` for processes at ≥ 15% of the machine's CPU or ≥ 30% GPU over 1 s. CPU is a share of the whole machine, and Hyprland is left out.
- `hog-warn`: after `Theme.hog.samples` (3) polls of `Theme.duration.hogPoll` (4 s) above `Theme.hog.cpu` (50) or `Theme.hog.gpu` (80), `bar/HogWatch.qml` shows.
- `hog-clear`: the label fades once the process calms or exits.
- `hog-setting`: Settings → Misc → "Warn about heavy processes" is saved as `hog=` in `~/.config/ummitos/desktop.conf`.

## How to get to it (user POV)

- It is on by default and needs no key. Run something heavy (a 4K video render) and watch the bar.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- The shell runs `$HOME/script/misc/proc-hogs.sh`. `up.sh` copies it into the fake HOME before the shell starts.
- `ffmpeg` is installed. The stack shares `/proc` with the host, so a host process is seen.

Steps (proven 2026-11-06):

- **Sampler.** Run `shellcheck script/misc/proc-hogs.sh`. While ffmpeg runs (below), `script/misc/proc-hogs.sh` prints an `ffmpeg` line.
- **Warn.** Start `timeout 30 ffmpeg -loglevel error -f lavfi -i testsrc2=size=3840x2160:rate=60 -c:v libx264 -preset slow -f null - &`, which uses about 50 to 80% of a 20-thread machine. Take `shot.sh hog-N` at 4, 8, 12 and 16 s and crop the top 44 px. Nothing shows at 4 and 8 s; at 12 s and after, the bar reads "⚠ ffmpeg CPU NN%".
- **Clear.** About 15 s after ffmpeg ends, the label is gone.

## Gotchas

- `-preset medium` reads about 30% on 20 threads, which is under the 50% threshold, so nothing shows. Use `slow`, or count threads with `nproc` and pick a load that crosses 50%.
- If the label shows after one or two polls, the Timer is running back to back again. It must not be gated on `sampler.running`.
- If `proc-hogs.sh` is missing when the shell starts, `qs.out` gets one "Process failed to start … proc-hogs.sh" and ProcWatch stops polling until the setting is turned off and on again. The health check (Super+H) reports the missing script.
- GPU use is readable only for the user's own processes, and the stack's headless output barely uses the GPU. GPU warnings are not proven here.
