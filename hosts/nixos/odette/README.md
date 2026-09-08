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
`dsm_calib_temp_{0..3}` in RO VPD. This unit has none (coreboot log:
`failed to find key in VPD: dsm_calib_r0_0`). ChromeOS's calibration failure
path selects `safe_mode_volume: 138` (-11 dB) on all four amplifiers.
The user reports matching loudness at 138; the comparison device's actual
calibration state has not been read. The native UCM's HiFi verb sets 138 directly
(`overlays/24-redrix-firmware/ucm/linux-adaptation.patch`), so selecting HiFi alone applies
both the boot sequence and the safe-mode gain; `redrix-audio-boot.service`
does nothing beyond that selection.

The Linux driver reports zero cached calibration values, while the hardware
registers contain nonzero blob defaults. This is not evidence of the comparison
unit's calibration state or of equivalent thermal protection.

### One speaker, one volume control

Select **Speakers** in KDE. WirePlumber's Smart Filters policy transparently
inserts CRAS correction for applications targeting that physical output.
The Speaker slider and mute are applied after processing; internal filter gain
is unity. There is no second user-facing Redrix volume or fixed 70% limit.
Amplifier settings are independent of that software volume.

`redrix-speaker-dsp.service` starts with the user PipeWire service. DSP runs in
a separate process, not inside the main audio server. It is restarted on failure
and follows PipeWire/WirePlumber restarts. If it exits, ordinary Speaker playback
can continue without correction; existing streams regain correction on restart.

Two WirePlumber scripts provide desktop integration:

- `hide-filter.lua` hides the internal sink/output from KDE's audio applet,
  shortcuts, System Settings, and PulseAudio volume controllers. Playback clients
  retain access because PipeWire requires it for links to the filter. Native
  diagnostic tools such as `pw-dump` still show the internal graph.
- `monitor-target.lua` keeps sink-monitor capture and level meters on the real
  output, rather than letting Smart Filters redirect them to the playback-only
  internal filter.

Headphones, Bluetooth and HDMI remain separate outputs, without the Redrix
speaker correction. The filter never falls back to them when its speaker target
disappears. Physical jack detection and automatic device selection remain the
responsibility of the existing UCM/WirePlumber policy.

The old EasyEffects service, Redrix preset and autoload entries are no longer
configured on Odette. Do not add another speaker EQ in front of this chain.

### Native configuration versus custom policy

Audio samples are processed in CRAS C code and PipeWire; Lua never processes
samples. Standard WirePlumber Smart Filters provide automatic insertion.
The two custom scripts only cover desktop visibility and sink-monitor routing.

With PipeWire 1.6.6/WirePlumber 0.5.14, a hardware-free native-only probe still
exposed the extra filter sink through PulseAudio when `node.hidden=true` and
`device.class=filter` were set. Plasma 6.6.6's applet can filter virtual devices,
but its System Settings page does not enable that same filter. Removing the
visibility policy would therefore not preserve the single-Speaker interface.
The upstream smart-filter hook also still redirects sink-monitor capture; the
monitor policy preserves the real output and its volume for meters/recording.

### Comparison and remaining gaps

- Compared with the former EasyEffects profile, EQ now uses the CRAS biquad
  implementation and compression retains its native knee, crossover, adaptive
  release and implicit makeup gain instead of translating numbers into LSP.
  The final EasyEffects profile had its compressor bypassed, so it did not
  reproduce this dynamic processing at all. The additional EasyEffects limiter
  is absent, matching the recovered two-stage DRC/EQ configuration.
- The desktop has one volume stage after correction, with no fixed software
  attenuation. Its cubic percentage mapping is not ChromeOS's explicit volume
  table. Both curves end at 0 dB at 100%; this alone does not prove equal SPL.
- The C implementation is pinned to an older Android-hosted CRAS copy.
  Source inspection against R151 is not a numerical equivalence test;
  reference-output and acoustic comparisons are still needed.
- CRAS's nominal 6 ms lookahead is present in the processing, but the LADSPA
  adapter does not report a `latency` control port to PipeWire. A/V latency and
  ChromeOS's board-specific timing compensation have not been matched.
- Amplifier boot initialization is not ordered against user-session PipeWire;
  it still relies on the card being ready when the system unit executes. Full
  machine suspend/resume, physical jack detection and long-duration behavior
  need hardware validation.

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
assessed. This is the only firmware/topology combination Odette boots.

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
files. The complete installed package has the same NAR hash as before this
source migration, with noise reduction both enabled and disabled.
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
- CRAS's named NR/AEC modifiers are not exposed as unsupported ACP media-role
  modifiers. The configured NR state is applied with the microphone route;
  firmware AEC stays off. No new automatic conferencing policy is implied.
- CRAS-internal Echo Reference/SCO PCMs remain accessible to ALSA but are not
  advertised as extra desktop microphones/speakers. PipeWire manages Bluetooth.

`DspName` and `IntrinsicSensitivity` are retained as OEM metadata, not interpreted
as PipeWire DSP activation or an extra microphone gain. The existing explicit
CRAS speaker filter is still needed. Full CRAS processing-policy parity is not
claimed.

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

### Microphone gain

With the plain channel selection above, the microphone was audibly very quiet.
ChromeOS's UCM declares `IntrinsicSensitivity "-2600"` for this device. CRAS
reads that and applies **software gain** `DEFAULT_CAPTURE_VOLUME_DBFS - IntrinsicSensitivity = -600 - (-2600) = +2000` (+20 dB; `cras_alsa_io.c`,
`cras_system_state.h`, release-R151) whenever a node declares
`IntrinsicSensitivity`; without reproducing that gain, Linux only gets the
unamplified microphone signal.

The `route` PCM applies the same +20 dB via its `ttable.0.0 10.0` coefficient
(a linear gain, not a channel on/off switch), alongside the channel selection
and format conversion already described above. `IntrinsicSensitivity` remains
in the UCM device as OEM metadata for documentation; it does not independently
drive any Linux gain.

`noiseReduction = true` in the host's `chromeosUcm` package override enables RTNR
when the microphone device is enabled. Set it to `false` and rebuild to persist
an unprocessed-noise-reduction comparison. For a temporary A/B while recording:

```bash
nix shell nixpkgs#alsa-utils -c amixer -c sofrt5682 cset 'name=RTNR10.0 rtnr_enable_10' off
nix shell nixpkgs#alsa-utils -c amixer -c sofrt5682 cset 'name=RTNR10.0 rtnr_enable_10' on
```

Re-enabling the UCM device restores the configured setting. This is not a KDE
noise-cancellation toggle. The recovered `AEC_Off.bin` initializes the Google
RTC component with firmware AEC disabled, leaving conferencing applications
free to handle echo cancellation without an always-on second AEC stage.

Verification: PipeWire's ACP probe accepted the native HiFi profile with eight
devices/ports: six outputs, one internal microphone and one headset microphone.
The route-based ACP probe exercised the plain PCM mapping; it was not a
rendered Plasma test. Native route enable/disable and HiFi re-selection ran
successfully, with all four amplifier gains remaining 138 after initialization.
Direct capture through the `route` PCM returned 48,000 mono S16_LE frames with
nonzero samples. The separate room recordings at -92.8 and -52.5 dBFS RMS
differ by 40.3 dB, not 20.2 dB, and cannot establish the gain ratio because
they contain different input signals. The +20 dB setting comes from the CRAS
formula and the route coefficient, not that uncontrolled comparison. These were
room-sound tests, not a controlled speech recording; they do not establish
speech quality, whether +20 dB is the right level for this specific
microphone/room, physical jack insertion, HDMI audio or suspend/resume
behavior. All temporary board-profile/mixer changes and test files used during
development were restored/removed; no extra background service or persistent
state remains as a result.

### Verification

The plugin check exercises descriptor lifecycle, buffers from 0 through 16385
frames, in-place processing, and block-size consistency at 44.1/48/96 kHz,
including AddressSanitizer and UndefinedBehaviorSanitizer runs.

Run the retained plugin checks with:

```bash
nix build .#nixosConfigurations.odette.pkgs.redrix.cras-dsp --no-link -L
```

During implementation, a separate virtual-device harness verified transparent
playback, volume/mute, output switching, monitor capture and process recovery.
That harness was removed to keep the repository small; these are historical
verification results, not ongoing integration coverage. Changes to routing or
desktop policy require a new smoke test. Physical jack behavior, full-machine
suspend/resume and acoustic quality still need hardware testing.

### Applying the change

Build and activate the default configuration:

```bash
sudo nixos-rebuild switch --flake .#odette
```

Then reboot into the newest ordinary NixOS generation. No `chromeos-sof`
specialisation needs to be selected. Older generations (and their historical
specialisation entries) may remain in the boot menu for rollback; this change
does not delete them. A WirePlumber restart alone cannot change loaded SOF
firmware, so reboot when migrating from the old community-firmware entry.

Select **Speakers** and **Internal Microphone** in KDE. The separate headset
microphone is intentional; there should be no second built-in `Mic2`.
Start playback at moderate volume and test a spoken microphone recording.

Diagnostics:

```bash
wpctl status -n
journalctl --user -u redrix-speaker-dsp.service -n 50 --no-pager
```

For an unprocessed comparison, stop `redrix-speaker-dsp.service`; keep Speakers
selected. Starting it again restores the correction.
