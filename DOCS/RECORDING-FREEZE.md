# Known issue: the screen freezes after stopping a long recording

When a long screen recording stops, Hyprland freezes the whole screen, mouse included, for a while. The freeze grows with roughly the square of the recording's length. Nothing is lost: the video is saved, and the desktop comes back on its own.

Found on 2026-10-30 with Hyprland 0.56.2 and wl-screenrec 0.3.2. It is not fixed yet.

## Measured on this machine

Every run used DP-2 at 2560x1440 and 144 Hz, with `avc`, `5 MB` and `-m 60`, writing to `/mnt/4tbhdd/Record`.

| Recording | How it stopped | Hyprland not answering after the stop |
|---|---|---|
| 3 min | `kill -INT` on wl-screenrec | under 0.3 s |
| 10 min | a click on the bar's recording pill | about 3.5 s |
| 20 min | `screen-record.sh`, the same script the pill runs | about 20–25 s (every `hyprctl` call timed out at 5 s) |
| 26 min | the owner's own recording | "a few minutes" (reported, not measured) |

The recorder itself always exits fast: `screen-record.log` says "stop took 169–187 ms". The shell kept answering IPC in under 40 ms the whole time. During the freeze, Hyprland's main thread was running (`R`), not waiting on the disk. The kernel log is clean. Hyprland logs `[Screenshare] Stopped screenshare session for (monitor): DP-2` only once the freeze is over.

## Cause

There are two bugs, one in each program, and both are upstream:

1. **wl-screenrec leaks one Wayland object per frame.** For each frame, `queue_frame_capture` in `src/main.rs` calls `self.dma.create_params(…)`, then `create_immed(…)`. It never calls `wl_buffer_params.destroy()`. `WAYLAND_DEBUG=1` over 5 seconds showed 473 `zwp_linux_dmabuf_v1.create_params` requests and no `zwp_linux_buffer_params_v1.destroy`. Every other per-frame object is destroyed. At 60 fps, a 20-minute recording leaves about 72,000 params objects.
2. **Hyprland frees them in quadratic time.** `CLinuxDMABUFProtocol::destroyResource` in `src/protocols/LinuxDMABUF.cpp` (around line 596 at v0.56.2) runs `std::erase_if(m_params, …)` over the whole vector for each resource it frees. When the client disconnects, all N params are freed one after another, which costs about N²/2 steps on the main thread. Rendering and input wait until it finishes.

Neither Hyprland's file descriptors nor its memory grew during a 60-second recording. The leaked objects carry no fd, and each one is small.

## The fix upstream

wl-screenrec needs one line, `wl_buffer_params.destroy();` after `create_immed(…)`. As of 2026-10-30, upstream (`russelltg/wl-screenrec`, last commit 2026-09-25) does not have it. Hyprland could keep params in a set, or swap and pop, instead of running `erase_if` over a vector, but the client leak is the real fault.

## Alternatives in UmmItOS

None of these has been tried yet.

- **Wait for upstream.** Send the one-line PR to wl-screenrec, then nothing in UmmItOS changes. Long recordings freeze until a release ships the fix.
- **Build a patched wl-screenrec.** Use the AUR `wl-screenrec-git` PKGBUILD plus the one-line patch. The fix is real, but UmmItOS would have to carry a patched package until upstream merges.
- **Record in segments.** `screen-record.sh` restarts wl-screenrec every few minutes and joins the pieces with `ffmpeg -c copy`. Each restart costs a short freeze (about 1 s at 5 minutes) and a small gap in the video.
- **Switch recorders.** `gpu-screen-recorder` (extra 6.1.6) and `wf-recorder` (extra 0.6.0) are both in the Arch repos. Before switching, check each with `WAYLAND_DEBUG=1` for the same leak: count `create_params` against `zwp_linux_buffer_params_v1.destroy`. `screen-record.sh`, the Record settings and the package list would all change. OBS and Kooha record through the portal (xdg-desktop-portal-hyprland and PipeWire), which is a larger change.
- **Lower the frame rate.** The leak counts frames, so 30 fps halves the object count and cuts the freeze to about a quarter. This only softens the freeze, it does not remove it.
- **Only warn.** Settings → Record could say that a long recording freezes the screen for a moment when it stops.

## Reproduce

```sh
f=/tmp/probe.mp4
WAYLAND_DEBUG=1 timeout -s INT 5 wl-screenrec -b "5 MB" --codec avc -m 60 --low-power=off -o DP-2 -f "$f" 2>/tmp/wd.log >/dev/null
grep -c 'zwp_linux_dmabuf_v1@[0-9]*.create_params' /tmp/wd.log    # ~470
grep -c 'zwp_linux_buffer_params_v1@[0-9]*.destroy' /tmp/wd.log   # 0
rm -f "$f" /tmp/wd.log
```

To time the freeze, record for 10 minutes, stop, and time `hyprctl -j activeworkspace` once every half second for the next 30 seconds.
