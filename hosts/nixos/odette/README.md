# ⛄️ Odette

HP Elite Dragonfly chromebook

## Audio

The Chromebook UCM configuration and MAX98390 firmware provide the hardware
baseline. `redrix-audio-boot.service` applies the Redrix UCM boot sequence.

`pkgs.redrix.cras-dsp` uses an older Chromium-derived DSP implementation and
parameters from recovery image 16733.54.0 (`/etc/cras/redrix/dsp.ini`). Acoustic
equivalence to that ChromeOS release has not been demonstrated.

The four packaged MAX98390 DSM blobs (left/right and tweeter left/right) were
compared byte-for-byte with `/lib/firmware/dsm_param_*_Google_Redrix.bin` in
recovery 16733.54.0: all four match, at 712 bytes each. This verifies the
packaged parameter files, not per-device calibration state or runtime loading.

### One speaker, one volume control

Select **Speakers** in KDE. WirePlumber's Smart Filters policy transparently
inserts CRAS correction for applications targeting that physical output.
The Speaker slider and mute are applied after processing; internal filter gain
is unity. There is no second user-facing Redrix volume or fixed 70% limit.
Amplifier settings are independent of that software volume and remain at their
Chromebook UCM values.

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
  attenuation. However, its cubic percentage mapping is not ChromeOS's explicit
  volume table. Matching percentages are not a loudness calibration.
- The C implementation is pinned to an older Android-hosted CRAS copy, not the
  recovery release's exact revision/build. Reference-output and acoustic
  comparisons are still needed before claiming bit-identical ChromeOS output.
- CRAS's nominal 6 ms lookahead is present in the processing, but the LADSPA
  adapter does not report a `latency` control port to PipeWire. A/V latency and
  ChromeOS's board-specific timing compensation have not been matched.
- Amplifier boot initialization is not ordered against user-session PipeWire;
  it still relies on the card being ready when the system unit executes. Full
  machine suspend/resume, per-device calibration, physical jack detection and
  maximum-volume/long-duration behavior need hardware validation.

The reported listening result is close to ChromeOS without obvious distortion
or pumping. It is useful subjective evidence, not a measured frequency-response
or maximum-SPL match.

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

After switching the NixOS configuration, restart the user WirePlumber service to
load the policy scripts, then ensure the DSP service is started:

```bash
systemctl --user restart wireplumber.service
systemctl --user start redrix-speaker-dsp.service
```

Select **Speakers** once in KDE to replace any saved default from the old
`redrix_chromeos_sink` setup. Begin at a moderate volume; normal operation needs
only the Speaker slider. No reboot or main PipeWire restart is required.

Diagnostics:

```bash
wpctl status -n
journalctl --user -u redrix-speaker-dsp.service -n 50 --no-pager
```

For an unprocessed comparison, stop `redrix-speaker-dsp.service`; keep Speakers
selected. Starting it again restores the correction.
