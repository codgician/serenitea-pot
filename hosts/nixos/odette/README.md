# ⛄️ Odette

HP Elite Dragonfly chromebook

## Audio

### Current audio path

Select **Speakers** and **Internal Microphone** in KDE. Both are standard
`libpipewire-module-filter-chain` endpoints, created by WirePlumber's upstream
`node.software-dsp` policy when their corresponding ALSA devices appear:

```text
applications -> Speakers filter [CRAS DRC -> EQ -> volume/ramp] -> raw ALSA speaker
applications <- Internal Microphone filter [APM -> attenuation] <- raw PCM99 channels 0/1
```

Plasma's tray volume applet hides virtual devices by default. Enable **Show
virtual devices** in the volume icon's context menu (or the applet's **More
actions** menu) to display these endpoints there. System Settings can show them
even while the tray list is empty. This only changes the applet's display
filter; it does not expose the hidden raw backends or bypass DSP.

`software-dsp.nix` binds each filter to exactly one backend. Physical node names
gain a `.raw` suffix; the public endpoints retain the previous node names and
desktop descriptions. Headset, headphones, HDMI and Bluetooth are not matched
by these rules.

The public speaker sink uses `capture.volumes`; the public microphone source
uses `playback.volumes`. Both map native channel volume to the corresponding
LADSPA volume ports. Backend adapters and private connecting streams
keep their software gain at unity, and private streams do not restore separate
volume/target state. The public endpoints alone own desktop volume and mute.
PulseAudio's reported dB is still the nominal cubic-control value, not the
board-specific applied gain.

**Endpoints with no saved state start at 0%.** WirePlumber stores their volume
and mute in native stream-properties state, independently of ALSA device Routes.
Choose the desired levels once; later filter recreation and session-manager
restarts restore them. Existing default-device names remain valid.

Upstream `hide-parent` removes ordinary clients' access to the raw backend,
including clients that connect later. A missing plugin leaves the processed
endpoint absent and the raw parent hidden; it must not become an unprocessed
fallback. Private streams have explicit targets, `node.dont-fallback`,
`node.dont-move` and `node.linger`, so they wait for their own hardware rather
than switching to another device. Parent removal releases its filter module.
After correcting a plugin/configuration load failure, restart WirePlumber to
recreate the filters. These session-policy permissions are not a security
boundary against a user who can use direct ALSA or privileged diagnostic clients.

The modules run inside WirePlumber, not a new DSP daemon. The profile requires
the native `pw.node-factory.adapter` feature, whose dependencies load client-node
and the export core once. Do not also load those modules in `context.modules`:
that duplicates native component registration when hardware features activate.
PipeWire has no local audio source patches; its board-specific package override
selects the UCM through alsa-lib. Only WirePlumber needs the LADSPA package.

Odette selects WirePlumber from `pkgs.unstable.wireplumber` (currently 0.5.17),
keeping only the PipeWire dependency override for the board's UCM. It includes upstream
[`5941c9f4bcc9`](https://github.com/PipeWire/wireplumber/commit/5941c9f4bcc97cbe1fefc581436b4c93a40d7e0d),
which prevents a partial `Props` object from erasing previously collected mute
or volume state. This matters for a speaker filter exposing both ordinary
volume properties and plugin-control properties. Use the pinned unstable package
for newer audio releases rather than maintaining a local version/source override.
No local WirePlumber source patches or custom Lua scripts are introduced.
Its existing state directory holds volumes; no new persistence or tmpfiles rule
is needed.

The speaker plugin imports all 101 entries of the pinned ChromeOS board curve.
Percentages round to integer table entries: 20% is -27 dB, 50% is -13.5 dB,
and 98-100% is 0 dB. Zero is silence; values above 100% cannot exceed unity.
The plugin implements 10 ms activation, 100 ms ordinary gain changes and
500 ms recovery from a zero target. **Native filter-chain mute and 0% silence
the stream immediately.** Do not lock the public stream mixer: that would break
native volume/mute restoration. The DRC reports its 288-frame predelay at
48 kHz, and the amplifier retains its safe-mode gain.

Filter-chain adds stream scheduling to the graph; plugin latency alone is not
end-to-end latency. Preserve the existing hardware quantum/headroom/no-suspend
settings and validate real playback, recording and suspend/resume before drawing
latency or power conclusions. The board's separate +64 ms timestamp offset is
still not applied without hardware timing verification.

### System microphone speech processing

The public **Internal Microphone** uses `redrix_mic_apm`, a stereo LADSPA adapter
around Nixpkgs' WebRTC audio-processing library. Ordinary PipeWire/PulseAudio
applications, including KDE Recorder, receive this processed input without
per-application opt-in. The underlying raw node is not a second selectable
microphone. Direct ALSA capture bypasses the processing.

The ALSA route stays at unity. WebRTC applies high-pass filtering and high-level
noise suppression, followed by adaptive digital AGC2. Fixed +20 dB sensitivity
compensation is applied inside AGC2 immediately before its limiter, not through
WebRTC's capture pre-gain (which would hard-clip before processing). AGC1 and
hardware/analog gain control are disabled. AGC2 starts at 0 dB adaptive gain and
permits up to 30 dB. Its pre-fixed-gain noise ceiling is -70 dBFS, accounting for
the following +20 dB compensation to target -50 dBFS output noise. The two
settings are coupled in code, so changing compensation preserves the target.

The desktop slider attenuates **after** APM so AGC cannot undo the user's volume
choice. Positive percentages use `0.4 * (percent - 100)` dB; zero/mute is silence,
including already buffered audio. Left/right balance is independent. Requests
above 100% cannot amplify the limited output.

| Input slider | Attenuation relative to APM output |
| --- | --- |
| 20% | -32 dB |
| 50% | -20 dB |
| 100% and above | 0 dB |
| 0% or muted | Silence |

100% means the full normalized APM output. The slider retains a 20 dB interval
between 50% and 100%. This is a system speech policy, not an exact reproduction
of ChromeOS's per-stream gain/APM decisions.
The reference's active Chrome recording used CRAS AEC; its browser-side effects
were not established. Do not claim identical noise suppression or acoustics.

AEC is deliberately disabled here: the existing speaker monitor is before its
DRC/EQ/volume and is not a validated echo reference. Do not enable AEC with that
signal merely because a module accepts it. Applications may still provide AEC;
disable their additional noise suppression/AGC where possible to avoid double
speech processing. This system policy is aimed at voice, not transparent music
or measurement recording. Headset, USB and Bluetooth microphones are unchanged.

APM operates at 48 kHz in 480-frame blocks. The adapter accepts arbitrary host
quanta, uses fixed instance buffers, and reports its 480-frame (10 ms) buffering
through the LADSPA latency port. This excludes WebRTC's internal filter delay;
it is not an end-to-end latency measurement. Volume changes do not reset APM.
Activation resets processing/buffers; a processing error logs and silences the
instance rather than falling back to unprocessed, amplified microphone audio.
The adapter does not claim LADSPA hard-real-time certification for WebRTC.

The speech processor is maintained in `redrix-mic-apm.cpp`; recheck API changes,
gain/limiter behavior, noise handling and CPU cost when updating WebRTC.

### Reference baseline and amplifier firmware

Odette uses Nixpkgs' unmodified `pkgs.sof-firmware` with its paired ADL IPC3
firmware and MAX98390/RT5682 topology. The same-model ChromeOS 16805.10.0
(R154 beta) device remains the reference for board tuning, amplifier settings
and microphone routing, not the source of the currently selected SOF binaries.
`pkgs.redrix.chromeos-ucm` adapts that board UCM to ALSA UCM2 and the stock topology.

`pkgs.redrix.cras-dsp` implements speaker DRC/EQ and the speaker volume curve. The
reference's `dsp.ini` and `card_settings` are byte-identical to those originally
extracted from recovery 16733.54.0; changing firmware is not a reason to retune
these parameters. Full acoustic and CRAS policy equivalence is not claimed.

Treat the reference system's shipped board tuning as the source of truth. Keep
shared data consistent; distinguish per-unit measurements or hardware/firmware
state only with concrete provenance, not from a control's name alone.

The four packaged MAX98390 DSM blobs (left/right and tweeter left/right) were
compared byte-for-byte with `/lib/firmware/dsm_param_*_Google_Redrix.bin` in
recovery 16733.54.0 and on the inspected R154 reference: all four match, at 712
bytes each. This verifies parameter files, not per-device calibration state.

These four files are fetched from Google's
[`dsm-param-redrix-1.0.tar.bz2`](https://storage.googleapis.com/chromeos-localmirror/distfiles/dsm-param-redrix-1.0.tar.bz2),
with a pinned SHA256. The archive was checked against the ChromiumOS package
Manifest; the four installed files match the previous individual download
hashes. Its two generic DSM files are intentionally not installed.

### Amplifier gain: ChromeOS safe mode

ChromeOS UCM writes `Digital Volume` 153/155 and then runs `sound_card_init boot_time_calibration` per `/etc/sound_card_init/redrix.MAX98390.yaml`. That
workflow requires factory calibration keys `dsm_calib_r0_{0..3}` and
`dsm_calib_temp_{0..3}` in RO VPD when valid prior calibration is unavailable.
Both Odette and the inspected reference lack the required factory VPD entries.
The reference's boot log explicitly records a failed calibration attempt and
`set_safe_mode: true`; its four Digital Volume controls are 138 (-11 dB).
The native HiFi verb sets 138 directly. It does not run calibration, choose
per-unit Rdc/temperature values or reproduce ChromeOS's thermal-history logic.
WirePlumber's UCM selection owns initialization; no separate service re-selects
HiFi during a session.

The reference's nonzero ALSA calibration cache differs from Odette's zero cache.
The MAX98390 `DSM Rdc` and `DSM Ambient Temp` getters return driver fields, not
register readback; calibration readout updates those fields without applying
them to the DSP. Both devices' regmap bytes at `0x2390` through `0x2394` match
the shipped DSM defaults (L/R/TL/TR Rdc: 541518/546910/606431/606431;
temperature: 1069/1087/893/937). Thus zero cache values do not mean missing DSP
configuration. Writing the reference's measured cache values would replace
already-matching system defaults. Do not copy another unit's measurements.
See the [driver getters and calibration readout](https://chromium.googlesource.com/chromiumos/third_party/kernel/+/chromeos-6.6/sound/soc/codecs/max98390.c).

### Monitor and processing boundaries

The public speaker filter's monitor is before its DSP and volume. The hidden
physical backend's monitor is after the filter, but is only available to trusted
diagnostics/processing contexts. Neither is a measurement of acoustic SPL.
AEC still requires a validated reference and hardware timing; changing the graph
layout does not automatically make either monitor a correct echo reference.

The old EasyEffects presets/service are not configured. Direct ALSA clients
bypass the PipeWire graphs, including microphone gain compensation; use the
desktop/PipeWire path for the tuned behavior. Full CRAS per-stream APM policy,
firmware AEC selection and acoustic/driver equivalence remain outside this port.

### Stock Nixpkgs SOF firmware

The host selects `pkgs.sof-firmware` directly; there is no local SOF binary
repackaging, source patch, version override or vendored payload. At this
migration, stable and unstable Nixpkgs both provide package `2025.12.2`.
Its ADL IPC3 image reports firmware **2.2.0-57864**, IPC ABI **3.22.1**.
The package also contains IPC4 images, but this host does not select them.

The selected files and validated SHA256 values for this package are:

```text
intel/sof/community/sof-adl.ri              e3489dcb277e87eee8bc091ab7d51163a63c85541c22522775122b54263769f3
intel/sof-tplg/sof-adl-max98390-rt5682.tplg  76ce8281301f63b35844ae029fced78a5285d3de52c6a7fde90d9096d2c9a822
```

Only `snd_sof.tplg_filename=sof-adl-max98390-rt5682.tplg` is explicitly set.
Linux 7.3-rc2 selects IPC3 on Alder Lake; the `Google_Brya` DMI family selects
`intel/sof/community` automatically. Keep the topology filename override because
DMI quirks can choose another board's topology. Recheck these defaults after
kernel or BIOS updates; a `community` directory name alone does not identify a
firmware version.

Offline comparison with the former ChromeOS topology established:

- Speaker PCM0 remains 48 kHz stereo, with S16_LE supported. SSP1 retains the
  same four-slot, 32-bit framing, 19.2 MHz MCLK and 6.144 MHz BCLK.
- PCM99 remains a four-channel S32_LE, 48 kHz DMIC stream. UCM still selects
  channels 0/1 unchanged, and the existing host APM remains in place.
- All nine hardware-link fixed configurations match. The speaker demux payload
  also matches apart from its ABI header; all required component UUIDs occur in
  the stock firmware's matching log dictionary.
- Stock speaker processing is PCM -> PGA -> demux -> SSP1, with no firmware
  speaker DRC/EQ. UCM sets `PGA1.1 1 Master Playback Volume` to `32,32` (0 dB),
  replacing the obsolete firmware DRC-disable control. The host CRAS DRC/EQ,
  101-entry speaker curve, gain ramps and MAX98390 DSM files are unchanged.
- The headset SSP0 clock-control value is 128 instead of 384: the stock topology
  omits the reference's MCLK-always-on bit. This is a hardware clock-policy
  difference, not an EQ change; jack insertion, start-of-playback and resume
  behavior still require hardware acceptance.

The real firmware version 2.2.0 selects the kernel's newer IPC3 teardown path,
unlike the reference image's reported 0.0.0. This is not a modified version field;
no kernel downgrade or audio kernel patch is introduced. The post-s2idle
hardware check below passed once; this does not establish long-term reliability.

Build and inspect the package with:

```bash
nix build .#nixosConfigurations.odette.pkgs.sof-firmware --no-link -L
```

After the approved boot/reboot migration, check the kernel log:

```bash
journalctl -k -b --no-pager --grep='sof-audio|Firmware file|Topology file|Firmware info|ABI|ipc.*error'
```

Expected paths are `intel/sof/community/sof-adl.ri` and
`intel/sof-tplg/sof-adl-max98390-rt5682.tplg`, using IPC3 and the version above.
These files load into DSP RAM; they do not flash the BIOS. Authentication,
topology-load or recurring IPC errors require investigation or the prior NixOS
generation, not mixing the stock image with the former ChromeOS topology.

### Native Redrix UCM provenance

`pkgs.redrix.chromeos-ucm` fetches the original `HiFi.conf` and
`sof-rt5682.redrix.conf` from the public ChromiumOS `board-overlays` repository,
pinned to commit `619bf55cd33588db1111f6481db62ad0ddc6dfd5`:
[Redrix UCM source directory](https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+/619bf55cd33588db1111f6481db62ad0ddc6dfd5/overlay-brya/chromeos-base/chromeos-bsp-brya/files/redrix/audio/ucm-config/sof-rt5682.redrix/).
Both original files match the inspected reference byte-for-byte (3,745 and 98 bytes).

`fetchzip` pins the unpacked directory hash because repeated Gitiles archive
downloads can differ in archive metadata while containing identical files.
`overlays/24-redrix-firmware/ucm/linux-adaptation.patch` then applies the local
Linux adaptations; there are no separately maintained copies of the two UCM
files. The new profile has no private RTC/RTNR control writes or AEC payload.

The native package copies the official `alsa-ucm-conf` base for ALSA discovery
and standard helpers. Its deliberate Linux adaptations are:

- UCM2 section syntax and `${CardId}` instead of a hard-coded card ID.
- Standard device IDs (`Headphones`, `Mic1`, `Headset`) retain desktop port
  classification and existing node names; PCM assignments remain OEM values.
- Mainline ALSA `JackControl` replaces CRAS's `JackDev`/`JackSwitch` mapping.
  The official ALSA HDMI helper supplies IEC958 switches for PCM 2–5.
- The headset routing switch is retained, but no nonexistent `Headset Mic`
  capture-volume element is advertised. Software capture volume remains usable.
- OEM capture channels 0 and 1 are exposed as stereo from PCM99's four-channel
  S32_LE hardware stream, using a plain unity ALSA route.
- OEM safe-mode amplifier gain 138 replaces the pre-calibration 153/155 values.
- The stock speaker PGA is explicitly set to 0 dB. The topology has no speaker
  DRC/EQ to disable; the existing native host filter performs that processing.
- No RTC/RTNR modifier or setting remains; host conferencing policy is separate.
- CRAS-internal Echo Reference/SCO PCMs remain accessible to ALSA but are not
  advertised as extra desktop microphones/speakers. PipeWire manages Bluetooth.

`DspName` and `IntrinsicSensitivity` are retained as OEM metadata. Explicit
native graphs implement speaker DSP and microphone compensation; PipeWire does
not infer them from those metadata keys. Full CRAS processing-policy parity is
not claimed.

### Internal microphone

Applications see one **Internal Microphone** device with a stereo stream, plus
the separate headset microphone. Stereo channels do not mean a second Mic2.

The reference UCM specifies `CaptureChannelMap "0 1 -1 ..."`. A short CRAS
capture confirmed PCM99 uses **S32_LE, four hardware channels, 48 kHz**. The
plain `redrix_mic` ALSA route selects channels 0 and 1 at unity and exposes two
logical channels. It does not average the four inputs or duplicate channel 0.
The corresponding PipeWire node requests S32_LE/48 kHz; speaker playback
requests the reference's S16_LE/48 kHz. Existing Linux scheduling/headroom
settings remain for stability rather than copying application buffer sizes.

The route avoids ACP's implicit SplitPCM mechanism. A hardware-free check loads
the installed UCM route with ALSA's parser, substitutes a four-channel file/null
PCM and verifies that distinct input channels 0/1 reach the two outputs unchanged.

### Verification

The package checks cover speaker DSP block-size consistency and in-place/lifecycle
behavior at 44.1/48/96 kHz, predelay reporting, the 101 speaker table entries,
capped gain and ramp timing. Microphone checks cover bounded output, arbitrary
host blocks, in-place processing, reactivation, post-AGC attenuation, buffered
mute and stationary-noise attenuation after adaptation. The noise threshold is
deliberately broad; it does not pin a particular WebRTC release's output.
AddressSanitizer and UndefinedBehaviorSanitizer instrument the local
adapters and speaker DSP; the linked WebRTC library is the normal package build.

Run the retained plugin checks with:

```bash
nix build .#nixosConfigurations.odette.pkgs.redrix.cras-dsp --no-link -L
```

`check-pipewire-graphs.py` runs unmodified PipeWire and WirePlumber in a private
runtime directory and D-Bus session. Native tone sources and a null sink stand
in for hardware; the same software-DSP rules and complete filter graphs are
loaded by WirePlumber. It checks hidden raw parents, safe first-use volume,
single gain ownership, post-APM balance, mute, the full speaker volume curve,
backend removal/recreation, unrelated-device isolation and native volume-state
restoration across WirePlumber restart. Missing microphone/speaker plugins must
reject explicit and default application requests rather than exposing raw audio.
The separate installed-UCM check still verifies selection of channels 0/1 from
distinct four-channel S32 samples with ALSA's parser and file/null PCMs.
`check-stock-topology.c` checks the selected binary topology's PCM0/PCM99 formats
and channel counts plus the speaker SSP clock and four-amplifier slot contract.
Speaker checks also change volume while idle and verify public readback against
rendered output without resending the volume at playback start. Non-default
stereo volume and mute must survive a WirePlumber restart; unmuting without a
new volume command must recover the saved gain, not a default.

Captures require a fresh, complete sample file and no recorder diagnostics.
PipeWire 1.6.x's `pw-cat --sample-count` can exit 1 after a complete recording
because that path does not mark the stream drained; this is checked alongside
the sample count rather than treated as success by exit status alone. Missing-DSP
probes require either a server `ENOENT` rejection or a live, registered,
non-running stream waiting for a target, as well as no captured/raw output.
An unrelated command failure or an unregistered hung process cannot pass.

Odette's `system.checks` uses its actual PipeWire and WirePlumber packages; a
failed routing regression prevents the system build. No embedded graph or local
PipeWire patch is used by these checks.
The generic package can also be tested with:

```bash
nix build .#nixosConfigurations.odette.pkgs.redrix.check-graphs --no-link -L
```

These tests never open physical audio devices. Real jack/clock behavior,
full-machine suspend/resume and acoustic results still need device acceptance.

#### Recorded post-s2idle hardware check

On 2026-09-12, with Linux 7.3-rc2 and stock SOF 2.2.0-57864, one user-performed
s2idle cycle followed by one controlled WirePlumber restart preserved HiFi and
both processed endpoints. Silent playback through the public speaker filter
reached the physical PCM and exited successfully. No negative PCM/IPC return
values, trace overruns or missed probes were recorded.

Tracing began **after** s2idle: it captured PCM teardown, reprobe and playback,
not that sleep transition. Closing the old speaker PCM decreased the observed
widget references from 2 to 1, preserving the static components; ACP setup and
close then took them 1 -> 2 -> 1. The earlier failing ChromeOS-firmware trace
instead showed 1 -> 0 and component destruction. This is evidence that the
tested stock combination avoids that failure path, not proof that every
suspend scenario is fixed. Repeated cycles, microphone recording, jack behavior
and acoustic equivalence still need hardware acceptance.

### Applying updates and troubleshooting

#### APM and userspace-only updates

Once the selected stock firmware and matching UCM are running, APM/plugin and
PipeWire configuration updates do not require a reboot. After approval:

```bash
sudo nixos-rebuild switch --flake .#odette
```

Changed audio units restart during activation, briefly interrupting playback
and recording. Verify that **Speakers** and **Internal Microphone** return as
defaults and retain their saved volume/mute state. Do not switch new UCM controls
onto incompatible running firmware.

#### Firmware, topology or boot-parameter updates

Install firmware/topology changes for the next boot after approval, then reboot.
Firmware, topology and the controls expected by UCM must become active together:

```bash
sudo nixos-rebuild boot --flake .#odette
sudo reboot
```

Do not use `switch`/`test` when changing firmware families: the old firmware
graph remains loaded, and changing files alone is insufficient. A user-service
restart cannot replace kernel-loaded SOF firmware. Boot the previous NixOS
generation to roll back the paired firmware and configuration.

Select **Speakers** and **Internal Microphone** in KDE. The separate headset
microphone is intentional; there should be no second built-in `Mic2`.
Start playback at moderate volume. For the current speech APM, microphone 100%
is the full processed output; lower it for attenuation, rather than interpreting
the percentage as the former static microphone gain.

#### Diagnostics

```bash
wpctl status -n
journalctl --user -b -u pipewire.service -u wireplumber.service --no-pager
```

The `gain:Volume Left/Right` custom-control values in a node's `Props` dump are
diagnostic snapshots, not continuous measurements of samples reaching ALSA.
They need not refresh on every ordinary volume update. Use the public
`channelVolumes`/`mute` values for desktop state, and a controlled post-DSP audio
measurement to establish actual gain. A differing custom-control snapshot alone
does not prove an incorrect volume or justify a volume-synchronization script.

Do not stop a DSP service for a dry comparison: there is no separate service
now. A deliberate raw-ALSA comparison bypasses the graphs and is not equivalent
to lowering the desktop volume.

### Provenance and remaining gaps

Git history retains the previous embedded-DSP implementation and removed
RTC/RTNR experiments. They are not alternative runtime configurations or
dependencies of the current audio path.

- Speaker DRC/EQ and the volume curve follow the recovered CRAS board tuning;
  this is not an EasyEffects approximation. No additional limiter is inserted.
- The C implementation is pinned to an older Android-hosted CRAS copy, not the
  reference's Rust DSP. Integer conversion/clipping boundaries and resampling
  are not guaranteed sample-identical to CRAS.
- The separate +64 ms board timestamp offset remains unapplied. It is timing
  compensation, not a tone effect; no A/V-sync issue has been reported here.
- Fixed amplifier gain 138 does not reproduce the full calibration workflow.
  Preserve the quantum/headroom/no-suspend settings until dedicated hardware
  testing justifies changing them.

An earlier eight-second synchronized capture on the reference and Odette had
almost identical DSP inputs. Processing the reference input with the local DSP
and comparing it with the reference's post-DSP loopback after warmup gave about
0.001 dB gain difference and correlations above 0.999997 in both channels. This
does not measure Odette's final acoustic output or establish acoustic identity.
