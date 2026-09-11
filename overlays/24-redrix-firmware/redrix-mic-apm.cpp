/* System speech processing for Redrix. SPDX-License-Identifier: BSD-3-Clause */
#include <ladspa.h>
#include <modules/audio_processing/include/audio_processing.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <memory>

namespace {
constexpr unsigned rate = 48000;
constexpr unsigned block = rate / 100;
constexpr float sensitivity_gain_db = 20.0f;
constexpr float output_noise_ceiling_dbfs = -50.0f;
enum Port { InputLeft, InputRight, OutputLeft, OutputRight, VolumeLeft,
            VolumeRight, Latency, PortCount };

struct Microphone {
  rtc::scoped_refptr<webrtc::AudioProcessing> apm;
  std::array<float *, PortCount> ports{};
  std::array<std::array<float, block>, 2> input{}, output{};
  std::array<float, 2> percent{-1, -1}, gain{};
  unsigned offset = 0;
  bool active = false;

  Microphone() : apm(webrtc::AudioProcessingBuilder().Create()) {
    if (!apm) return;
    webrtc::AudioProcessing::Config config;
    config.pipeline.multi_channel_capture = true;
    config.echo_canceller.enabled = false; // No validated speaker reference.
    config.high_pass_filter.enabled = true;
    config.noise_suppression.enabled = true;
    config.noise_suppression.level =
        webrtc::AudioProcessing::Config::NoiseSuppression::kHigh;
    // WebRTC's capture pre-gain hard-clips before noise suppression/AGC.
    // Apply sensitivity compensation inside AGC2, immediately before its limiter.
    config.gain_controller1.enabled = false;
    config.gain_controller2.enabled = true;
    config.gain_controller2.adaptive_digital.enabled = true;
    config.gain_controller2.adaptive_digital.initial_gain_db = 0;
    config.gain_controller2.adaptive_digital.max_gain_db = 30;
    config.gain_controller2.fixed_digital.gain_db = sensitivity_gain_db;
    // AGC2's noise ceiling is evaluated before the fixed +20 dB stage.
    config.gain_controller2.adaptive_digital.max_output_noise_level_dbfs =
        output_noise_ceiling_dbfs - sensitivity_gain_db;
    apm->ApplyConfig(config);
  }

  bool initialize() {
    const webrtc::StreamConfig stereo(rate, 2);
    const webrtc::ProcessingConfig format = {{stereo, stereo, stereo, stereo}};
    return apm && apm->Initialize(format) == webrtc::AudioProcessing::kNoError;
  }
};

LADSPA_Handle instantiate(const LADSPA_Descriptor *, unsigned long sample_rate) {
  if (sample_rate != rate) return nullptr;
  try {
    auto mic = std::make_unique<Microphone>();
    if (!mic->initialize()) return nullptr;
    return mic.release();
  } catch (...) {
    return nullptr;
  }
}

void connect(LADSPA_Handle handle, unsigned long port, LADSPA_Data *data) {
  if (port < PortCount) static_cast<Microphone *>(handle)->ports[port] = data;
}

void activate(LADSPA_Handle handle) {
  auto &mic = *static_cast<Microphone *>(handle);
  mic.input = {};
  mic.output = {};
  mic.offset = 0;
  mic.percent = {-1, -1};
  mic.active = mic.initialize();
  if (!mic.active) std::fputs("Redrix microphone: APM initialization failed\n", stderr);
  // Reports the adapter's fixed buffering, not APM's internal filter delay.
  if (mic.ports[Latency]) *mic.ports[Latency] = block;
}

void deactivate(LADSPA_Handle handle) {
  static_cast<Microphone *>(handle)->active = false;
}

void run(LADSPA_Handle handle, unsigned long frames) {
  auto &mic = *static_cast<Microphone *>(handle);
  if (mic.ports[Latency]) *mic.ports[Latency] = block;
  for (unsigned channel = 0; channel < 2; ++channel) {
    float value = mic.ports[VolumeLeft + channel]
                      ? *mic.ports[VolumeLeft + channel] : 0;
    value = std::isfinite(value) ? std::clamp(value, 0.0f, 100.0f) : 0;
    if (value != mic.percent[channel]) {
      mic.percent[channel] = value;
      // Preserve the 20 dB interval from 50% to 100%, but never boost APM's
      // limited output. Post-APM attenuation cannot be undone by AGC.
      mic.gain[channel] = value > 0 ? std::pow(10.0f, 0.02f * (value - 100)) : 0;
    }
  }
  if (!mic.active || !mic.ports[InputLeft] || !mic.ports[InputRight]) {
    for (unsigned channel = 0; channel < 2; ++channel)
      if (mic.ports[OutputLeft + channel])
        std::fill_n(mic.ports[OutputLeft + channel], frames, 0.0f);
    return;
  }
  const webrtc::StreamConfig stereo(rate, 2);
  for (unsigned long frame = 0; frame < frames; ++frame) {
    // Read both inputs before writing either output: supports in-place hosts.
    for (unsigned channel = 0; channel < 2; ++channel)
      mic.input[channel][mic.offset] = mic.ports[InputLeft + channel][frame];
    for (unsigned channel = 0; channel < 2; ++channel)
      if (mic.ports[OutputLeft + channel])
        mic.ports[OutputLeft + channel][frame] =
            mic.output[channel][mic.offset] * mic.gain[channel];
    if (++mic.offset == block) {
      const float *input[] = {mic.input[0].data(), mic.input[1].data()};
      float *output[] = {mic.output[0].data(), mic.output[1].data()};
      const int result = mic.apm->ProcessStream(input, stereo, stereo, output);
      mic.offset = 0;
      if (result != webrtc::AudioProcessing::kNoError) {
        std::fprintf(stderr, "Redrix microphone: APM processing failed (%d)\n", result);
        mic.active = false;
        mic.output = {};
        for (unsigned channel = 0; channel < 2; ++channel)
          if (mic.ports[OutputLeft + channel])
            std::fill_n(mic.ports[OutputLeft + channel] + frame + 1,
                        frames - frame - 1, 0.0f);
        return;
      }
    }
  }
}

void cleanup(LADSPA_Handle handle) { delete static_cast<Microphone *>(handle); }

const LADSPA_PortDescriptor port_descriptors[] = {
    LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO, LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO,
    LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO, LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO,
    LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL, LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL,
    LADSPA_PORT_OUTPUT | LADSPA_PORT_CONTROL};
const char *port_names[] = {"Input Left", "Input Right", "Output Left", "Output Right",
                            "Volume Left", "Volume Right", "latency"};
const LADSPA_PortRangeHint port_hints[] = {
    {0, 0, 0}, {0, 0, 0}, {0, 0, 0}, {0, 0, 0},
    {LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE, 0, 100},
    {LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE, 0, 100},
    {LADSPA_HINT_BOUNDED_BELOW, 0, 0}};

const LADSPA_Descriptor descriptor = {
    0x72647b, "redrix_mic_apm", 0, "Redrix system speech APM",
    "serenitea-pot", "BSD-3-Clause", PortCount, port_descriptors, port_names,
    port_hints, nullptr, instantiate, connect, activate, run, nullptr, nullptr,
    deactivate, cleanup};
} // namespace

extern "C" const LADSPA_Descriptor *redrix_mic_apm_descriptor() {
  return &descriptor;
}
