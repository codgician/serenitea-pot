# ⛄️ Odette

HP Elite Dragonfly chromebook

## Audio

Odette uses `pkgs.redrix.chromeos-ucm`: official ALSA UCM plus a Redrix profile
ported from ChromeOS recovery 16733.54.0, replacing the previously used
WeirdTreeThing community Chromebook overlay entirely. `pkgs.redrix.sof-firmware`
(the matched board-specific SOF firmware and topology from that same recovery)
is likewise the only firmware in use; there is no separate boot entry.

`pkgs.redrix.cras-dsp` uses an older Chromium-derived DSP implementation and
parameters from recovery image 16733.54.0 (`/etc/cras/redrix/dsp.ini`). Acoustic
equivalence to that ChromeOS release has not been demonstrated.

The four packaged MAX98390 DSM blobs (left/right and tweeter left/right) were
compared byte-for-byte with `/lib/firmware/dsm_param_*_Google_Redrix.bin` in
recovery 16733.54.0: all four match, at 712 bytes each. This verifies the
packaged parameter files, not per-device calibration state or runtime loading.

These four files are fetched from Google's
[`dsm-param-redrix-1.0.tar.bz2`](https://storage.googleapis.com/chromeos-localmirror/distfiles/dsm-param-redrix-1.0.tar.bz2),
with a pinned SHA256. The archive was checked against the ChromiumOS package
Manifest; the four installed files match the previous individual download
hashes. Its two generic DSM files are intentionally not installed.

### Amplifier gain: ChromeOS safe mode

ChromeOS UCM writes `Digital Volume` 153/155 and then runs `sound_card_init boot_time_calibration` per `/etc/sound_card_init/redrix.MAX98390.yaml`. That
workflow requires factory calibration keys `dsm_calib_r0_{0..3}` and
`dsm_calib_temp_{0..3}` in RO VPD when valid prior calibration is unavailable.
This unit has no factory entries (coreboot: `failed to find key in VPD: dsm_calib_r0_0`); that alone does not determine the comparison unit's state,
because ChromeOS may reuse calibration from its DSM datastore. Its handled
calibration-failure path selects `safe_mode_volume: 138` (-11 dB).
The user reports matching loudness with all four amplifiers at 138. The native
HiFi verb sets that conservative value directly; it does not reproduce
calibration, Rdc/temperature selection, or thermal-history decisions.
WirePlumber's normal UCM selection owns initialization. There is no competing
system service re-selecting HiFi and resetting RTNR while a session is active.

The Linux driver reports zero cached calibration values, while the hardware
registers contain nonzero blob defaults. This is not evidence of the comparison
unit's calibration state or of equivalent thermal protection.

### Device-owned processing and one volume control

Select **Speakers** and **Internal Microphone** in KDE. PipeWire's native
`audioconvert.filter-graph.0` embeds the processing in each physical ALSA node:

```text
Speaker: applications -> CRAS DRC -> EQ -> speaker gain/ramp -> ALSA
Mic1:    PCM99 channel 0 -> unity ALSA route -> float capture gain -> applications
```

The graph consumes the node's `channelVolumes` and mute changes directly through
`capture.volumes`. The adapter's ordinary software gain/mute is locked at unity,
so it cannot apply a second gain or cut off the plugin's mute ramp. Desktop
controllers still use the ALSA device Route for their requested volume/mute.
Low-level node Props can therefore show unity; PulseAudio's reported dB remains
the nominal cubic-control value, not the board-specific applied gain.

The speaker plugin imports all 101 entries from the pinned ChromeOS
`sof-rt5682.card_settings` `[Speaker]` section at build time. Desktop percentages
are rounded to the nearest integer table position; 20% is -27 dB, 50% is
-13.5 dB, and 98-100% is 0 dB. Zero is silence, and requests above 100% cannot
raise the actual speaker gain above unity. Amplifier gains remain independent.
Fractional/native requests follow this explicitly defined percentage policy.

Speaker amplitude ramps run sample-by-sample: activation starts from silence
over 10 ms, ordinary changes and mute take 100 ms, and leaving a zero target
takes 500 ms. Interrupted ramps continue from the current gain; an unchanged
target does not restart the ramp. Mute and a zero slider both reach the same
zero target. ChromeOS's separate resume/switch silence windows and exact client
event classification are not reproduced by these ramps.

There are no auxiliary sinks/streams, Smart Filters substitutions, visibility
exceptions, asynchronous gain-correction Lua, or standalone speaker-DSP service.
The graph follows ALSA node creation and destruction, eliminating the separate
process/link race and extra stream gains. DSP now shares its ALSA adapter host
instead of having a dedicated crash-isolation process. The local PipeWire patch
propagates explicit graph load/activation failures rather than publishing a dry
fallback. Graph replacement is disabled after initial configuration.

The LADSPA `latency` output reports the compressor's actual predelay (288 frames
at 48 kHz); PipeWire propagates it through port latency. This is reporting, not
an additional delay line. The ChromeOS board's separate +64 ms timestamp offset
has not been applied without checking existing hardware timing compensation.

One small WirePlumber script manages only the RTNR setting described below.
Its persistent settings use the already-persisted `/home`; no new service,
state directory or tmpfiles rule is required. Headset, headphones, HDMI and
Bluetooth are not matched by the internal speaker/microphone graph rules.

### Monitor and processing boundaries

With embedded device DSP, the standard sink monitor is the unmodified adapter
input, before the graph and its gain. It is not a measurement of the sound sent
to the speakers and is not automatically a suitable echo-cancellation reference.
Do not infer SPL or applied board gain from a monitor recording or `pactl` dB.

The old EasyEffects presets/service are not configured. Direct ALSA clients
bypass the PipeWire graphs, including microphone gain compensation; use the
desktop/PipeWire path for the tuned behavior. Full CRAS per-stream APM policy,
firmware AEC selection and acoustic/driver equivalence remain outside this port.

### Comparison and remaining gaps

- Compared with the former EasyEffects profile, EQ now uses the CRAS biquad
  implementation and compression retains its native knee, crossover, adaptive
  release and implicit makeup gain instead of translating numbers into LSP.
  The final EasyEffects profile had its compressor bypassed, so it did not
  reproduce this dynamic processing at all. The additional EasyEffects limiter
  is absent, matching the recovered two-stage DRC/EQ configuration.
- Speaker integer volume mapping and its unity maximum now match the board
  curve; actual acoustic equivalence is still not established.
- The C implementation remains pinned to an older Android-hosted CRAS copy.
  It is not the R151 Rust DSP, and integer conversion/clipping boundaries and
  resampling are not sample-identical to CRAS. No extra quantizer was added.
- The DRC delay is reported, but the separate +64 ms board timing offset still
  requires timing verification. Existing Linux quantum/headroom/no-suspend
  settings remain for stability, rather than copying CRAS buffer defaults.
- Fixed gain 138 does not reproduce the full amplifier calibration workflow.
  Mainline driver behavior, physical jack insertion, suspend/resume and long
  playback still need hardware comparison; source matches alone do not prove it.

With the earlier community SOF firmware the user reported matching loudness but
slightly coarser voices at maximum volume. After switching to the matched
Redrix SOF firmware and board topology, the two machines reportedly sound
almost identical. This is side-by-side listening evidence, not a measured
acoustic equivalence. An earlier capture at 65% volume and limited synthetic
checks did not establish the cause; firmware and topology changed together.

### ChromeOS SOF firmware

`pkgs.redrix.sof-firmware` packages the exact board-specific files from Google
brya recovery 16733.54.0. The three binaries are stored directly under
`overlays/24-redrix-firmware/sof-firmware/`; redistribution has not been
assessed. This is the firmware/topology configured for new Odette generations;
the running kernel and any older boot entries must be checked separately.

Build the package directly:

```bash
nix build .#nixosConfigurations.odette.pkgs.redrix.sof-firmware --no-link -L
```

Use the **redrix subdirectory for both firmware and topology**. An earlier
topology comparison inspected the generic ChromeOS topology, not this board
topology; the board file is 48,731 bytes and its speaker graph includes a
DEMUX. Current `alsatplg` rejects a bytes-control access flag when decoding
it; this has been confirmed compatible with the running mainline kernel
through boot testing (below), not through `alsatplg` decoding. Do not rewrite
that flag in the shipped binary to make decoding succeed.

`boot.kernelParams` in `hardware.nix` selects IPC3 and both Redrix-specific
paths. After `sudo nixos-rebuild switch --flake .#odette` and a reboot, verify
in the kernel journal:

```bash
sudo journalctl -k -b --no-pager --grep='sof-audio|Firmware file|Topology file|Firmware info|ABI|ipc.*error'
```

Confirm the loaded paths are `intel/sof/redrix/sof-adl.ri` and
`intel/sof-tplg/redrix/sof-adl-max98390-rt5682.tplg`. Firmware authentication,
topology-load or repeated IPC errors mean the firmware failed to load; roll
back to an earlier NixOS generation from the boot menu.

This loads DSP firmware into RAM; it does not flash the Chromebook firmware.
After a rebuild, verify both loaded paths and firmware ABI in the kernel
journal, check for topology/IPC errors, then test speakers, microphones,
headphones and suspend/resume. A successful package build is not a successful
hardware or acoustic test.

Related upstream discussion of ChromeOS board bundles and topology/IPC issues:
https://github.com/thesofproject/sof/issues/8563

### Native Redrix UCM provenance

`pkgs.redrix.chromeos-ucm` fetches the original `HiFi.conf` and
`sof-rt5682.redrix.conf` from the public ChromiumOS `board-overlays` repository,
pinned to commit `0e50126e09cc069570ad4b19bc629254a5e5bdf5`:
[Redrix UCM source directory](https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+/0e50126e09cc069570ad4b19bc629254a5e5bdf5/overlay-brya/chromeos-base/chromeos-bsp-brya/files/redrix/audio/ucm-config/sof-rt5682.redrix/).
Both original files match recovery 16733.54.0 byte-for-byte (4,470 and 98 bytes).

`fetchzip` pins the unpacked directory hash because repeated Gitiles archive
downloads can differ in archive metadata while containing identical files.
`overlays/24-redrix-firmware/ucm/linux-adaptation.patch` then applies the local
Linux adaptations; there are no separately maintained copies of the two UCM
files. Their earlier source-only migration preserved installed contents; the
later gain/policy changes described here intentionally modify the adaptation.
The vendored Redrix SOF binaries and AEC payload are unchanged.

The native package copies the official `alsa-ucm-conf` base for ALSA discovery
and standard helpers. Its deliberate Linux adaptations are:

- UCM2 section syntax and `${CardId}` instead of a hard-coded card ID.
- Standard device IDs (`Headphones`, `Mic1`, `Headset`) retain desktop port
  classification and existing node names; PCM assignments remain OEM values.
- Mainline ALSA `JackControl` replaces CRAS's `JackDev`/`JackSwitch` mapping.
  The official ALSA HDMI helper supplies IEC958 switches for PCM 2–5.
- The headset routing switch is retained, but no nonexistent `Headset Mic`
  capture-volume element is advertised. Software capture volume remains usable.
- OEM capture channel 0 is exposed as mono; S16_LE is required by the RTC stage.
- OEM safe-mode amplifier gain 138 replaces the pre-calibration 153/155 values.
- CRAS's named NR/AEC modifiers are not exposed as ACP media-role modifiers.
  HiFi initializes both off; WirePlumber applies the saved RTNR choice using a
  native bound control. Firmware AEC remains off; no call policy is implied.
- CRAS-internal Echo Reference/SCO PCMs remain accessible to ALSA but are not
  advertised as extra desktop microphones/speakers. PipeWire manages Bluetooth.

`DspName` and `IntrinsicSensitivity` are retained as OEM metadata. Explicit
native graphs implement speaker DSP and microphone compensation; PipeWire does
not infer them from those metadata keys. Full CRAS processing-policy parity is
not claimed.

### Internal microphone

KDE/applications see one **Internal Microphone**, plus the separate headset
microphone; there is no separate "Mic2" and no second boot entry to select.

The board pipeline is DMIC A/B → Google RTC processing → Realtek RTNR → PCM 99,
a two-channel PCM. ChromeOS's `CaptureChannelMap "0 0 -1 ..."` selects PCM
output channel 0 for both logical channels; CRAS does not average or downmix
the raw microphone array itself. `Mic1` in the native UCM opens a plain
alsa-lib `route` PCM (`redrix_mic`) that selects that channel, converts to the
**S16_LE** format the Google RTC component requires (it rejects S32_LE at
prepare), and reports one application channel. Both physical microphone lanes
remain enabled in the unmodified firmware topology; this does not alter
speaker tuning.

An earlier revision used UCM's `CaptureChannel0`/`CaptureChannelPos0` keys
instead. Those are not documented UCM2 syntax; PipeWire's ACP layer
(`alsa-ucm.c`: `ucm_get_split_channels`) reads them as a request to build a
`SplitPCM` node pair through WirePlumber's ALSA monitor Lua script
(`monitors/alsa.lua`), an internal implementation detail. The current UCM
package uses the `route` plugin instead, so PipeWire's ACP probe takes the
plain-PCM path and no `SplitPCM` node or WirePlumber-specific rule is needed
for routing, naming or capture format; the `Comment` in the UCM device supplies
the desktop description directly.

### Microphone gain and runtime noise reduction

The ALSA route now uses `ttable.0.0 1.0`: channel selection and the known-working
S16_LE hardware format only. The previous integer x10 gain could clip before a
later desktop attenuation. Compensation and UI gain are now combined in float.

CRAS derives intrinsic compensation from `-600 - (-2600) = +2000` centibels
(+20 dB). Redrix's default capture UI law is `0.4 * (percent - 50)` dB, separate
from that compensation. The graph applies their sum for positive percentages:

| Input slider | Combined gain relative to processed PCM99 |
| --- | --- |
| 20% | +8 dB |
| 50% | +20 dB |
| 100% and above | +40 dB maximum |
| 0% or muted | Silence |

**Zero remains silent intentionally.** CRAS's capture zero is -20 dB UI gain,
not mute; retaining Linux's zero-is-silent behavior avoids a surprising privacy
change. This is a documented deviation, not strict CRAS parity. Start speech
testing at 50%: the old Linux 100% and new 50% both provide nominal +20 dB.
The gain stage preserves float headroom rather than clipping before subsequent
application attenuation. A loud input can still clip when finally converted to
integer samples. These gains are not AGC and do not implement CRAS's per-stream
gain ownership, `IGNORE_UI_GAINS`, or APM pre/post-processing decisions.

RTNR uses PipeWire's native `api.alsa.bind-ctls` on the exact Mic1 node. Change
the persistent setting without rebuilding or restarting audio:

```bash
wpctl settings --save redrix.noise-reduction false
wpctl settings --save redrix.noise-reduction true
wpctl settings redrix.noise-reduction
```

The default is enabled. WirePlumber reapplies the latest desired value on node
recreation; hardware writes use `Props.params`, followed by a fresh parameter
query for verification rather than a stale cache comparison. No shell helper,
polling, duplicate UCM device-level writer or separate daemon is involved.
This is a CLI/runtime setting, not a new KDE toggle or CRAS provider arbitration.

AEC remains disabled through the original `AEC_Off.bin`. No system AEC/NS/AGC
was added, and empty `apm.ini` is not evidence that ChromeOS never uses host APM.
Applications can provide their own processing; automatic double-processing
avoidance and echo-reference alignment remain separate work.

Historical ACP/room-capture probes established that the mono route works, not
controlled gain or acoustic equivalence. The new gain checks use identical
synthetic inputs and actual PipeWire output; no new room recording is implied.

### Verification

The package checks cover DSP block-size consistency and in-place/lifecycle
behavior at 44.1/48/96 kHz, actual predelay reporting, the 101 speaker table
entries, capped gain, ramp timing/interruption, microphone float headroom and
zero/mute behavior, including AddressSanitizer and UndefinedBehaviorSanitizer.

Run the retained plugin checks with:

```bash
nix build .#nixosConfigurations.odette.pkgs.redrix.cras-dsp --no-link -L
```

An isolated PipeWire instance exercised the production graphs with synthetic
audio: speaker 20/50/100/150% produced -27/-13.5/0/0 dB, mic 20/50/100%
produced +8/+20/+40 dB without intermediate clipping, and zero produced silence.
Actual speaker output showed 100 ms mute and 500 ms unmute ramps. The full
DRC/EQ graph preserved the post-DSP volume ratio and reported 288 frames on its
ports. A missing required plugin rejected node creation instead of bypassing DSP.
A separate settings-policy instance exercised the real RTNR bound control via
an ALSA null PCM (no microphone recording), including saved state, rapid changes
and node recreation; the original hardware setting was restored.
These are smoke-test results, not permanent integration coverage or a deployed
hardware/acoustic acceptance test. Physical jack and full suspend/resume still
need testing after activation.

### Applying the change

Build and activate the default configuration:

```bash
sudo nixos-rebuild switch --flake .#odette
```

This gain/policy update does not change SOF firmware and does not itself need a
reboot. Switching the configuration restarts the relevant audio services. If
migrating from the old community firmware, reboot to load the Redrix firmware;
restarting WirePlumber cannot replace firmware already loaded by the kernel.
No specialisation is needed; older generations remain available for rollback.

Select **Speakers** and **Internal Microphone** in KDE. The separate headset
microphone is intentional; there should be no second built-in `Mic2`.
Start playback at moderate volume and microphone speech testing at 50%.

Diagnostics:

```bash
wpctl status -n
journalctl --user -b -u pipewire.service -u wireplumber.service --no-pager
```

Do not stop a DSP service for a dry comparison: there is no separate service
now. A deliberate raw-ALSA comparison bypasses the graphs and is not equivalent
to lowering the desktop volume or disabling RTNR.
