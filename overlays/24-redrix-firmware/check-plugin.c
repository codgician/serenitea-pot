/* Exercise the public LADSPA ABI without a running audio server. */
#include <assert.h>
#include <dlfcn.h>
#include <ladspa.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "redrix-speaker-curve.h"

#define FRAMES 16385UL

struct stereo_ports {
  unsigned long input_left;
  unsigned long input_right;
  unsigned long output_left;
  unsigned long output_right;
};

struct dsp_ports {
  struct stereo_ports audio;
  unsigned long latency;
};

struct speaker_ports {
  struct stereo_ports audio;
  unsigned long volume_left;
  unsigned long volume_right;
};

struct mic_ports {
  struct stereo_ports audio;
  unsigned long volume_left;
  unsigned long volume_right;
  unsigned long latency;
};

static void assert_close(float actual, float expected) {
  const float tolerance = 1e-5f * fmaxf(1.0f, fabsf(expected));
  assert(isfinite(actual));
  assert(fabsf(actual - expected) <= tolerance);
}

static unsigned long find_port(const LADSPA_Descriptor *descriptor,
                               const char *name,
                               LADSPA_PortDescriptor required_flags) {
  for (unsigned long port = 0; port < descriptor->PortCount; ++port) {
    if (!strcmp(descriptor->PortNames[port], name)) {
      if ((descriptor->PortDescriptors[port] & required_flags) == required_flags)
        return port;
      fprintf(stderr, "%s has incompatible port flags\n", name);
      abort();
    }
  }
  fprintf(stderr, "%s is missing a required port\n", name);
  abort();
}

static void assert_percent_range(const LADSPA_Descriptor *descriptor,
                                 unsigned long port) {
  const LADSPA_PortRangeHint *hint = &descriptor->PortRangeHints[port];
  assert(hint->HintDescriptor & LADSPA_HINT_BOUNDED_BELOW);
  assert(hint->HintDescriptor & LADSPA_HINT_BOUNDED_ABOVE);
  assert(hint->LowerBound == 0.0f);
  assert(hint->UpperBound == 100.0f);
}

static struct stereo_ports find_stereo_ports(const LADSPA_Descriptor *descriptor) {
  return (struct stereo_ports) {
    .input_left = find_port(descriptor, "Input Left",
                            LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO),
    .input_right = find_port(descriptor, "Input Right",
                             LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO),
    .output_left = find_port(descriptor, "Output Left",
                             LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO),
    .output_right = find_port(descriptor, "Output Right",
                              LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO),
  };
}

static const LADSPA_Descriptor *require_descriptor(
    LADSPA_Descriptor_Function entry, unsigned long index, const char *label) {
  const LADSPA_Descriptor *descriptor = entry(index);
  assert(descriptor != NULL);
  assert(!strcmp(descriptor->Label, label));
  assert(descriptor->instantiate != NULL);
  assert(descriptor->connect_port != NULL);
  assert(descriptor->activate != NULL);
  assert(descriptor->run != NULL);
  assert(descriptor->deactivate != NULL);
  assert(descriptor->cleanup != NULL);
  return descriptor;
}

static void connect_dsp(const LADSPA_Descriptor *descriptor, LADSPA_Handle handle,
                        struct dsp_ports ports, float *input[2],
                        float *output[2], float *latency) {
  descriptor->connect_port(handle, ports.audio.input_left, input[0]);
  descriptor->connect_port(handle, ports.audio.input_right, input[1]);
  descriptor->connect_port(handle, ports.audio.output_left, output[0]);
  descriptor->connect_port(handle, ports.audio.output_right, output[1]);
  descriptor->connect_port(handle, ports.latency, latency);
}

static void run_dsp(const LADSPA_Descriptor *descriptor, LADSPA_Handle handle,
                    struct dsp_ports ports, float *input[2], float *output[2],
                    float *latency, unsigned long quantum) {
  for (unsigned long offset = 0; offset < FRAMES;) {
    unsigned long count = FRAMES - offset;
    if (count > quantum) count = quantum;
    float *input_at_offset[2] = { input[0] + offset, input[1] + offset };
    float *output_at_offset[2] = { output[0] + offset, output[1] + offset };
    connect_dsp(descriptor, handle, ports, input_at_offset, output_at_offset,
                latency);
    descriptor->run(handle, count);
    offset += count;
  }
  descriptor->run(handle, 0);
}

static unsigned long expected_drc_delay(unsigned long rate) {
  unsigned long frames = (unsigned long)(0.006f * (float)rate);
  if (frames > 1023) frames = 1023;
  frames &= ~31UL;
  return frames < 32 ? 32 : frames;
}

static float process_dsp(const LADSPA_Descriptor *descriptor,
                         struct dsp_ports ports, float *input[2],
                         float *output[2], unsigned long quantum,
                         unsigned long rate) {
  LADSPA_Handle handle = descriptor->instantiate(descriptor, rate);
  assert(handle != NULL);
  float latency = NAN;
  connect_dsp(descriptor, handle, ports, input, output, &latency);
  descriptor->activate(handle);
  run_dsp(descriptor, handle, ports, input, output, &latency, quantum);
  descriptor->deactivate(handle);
  descriptor->cleanup(handle);
  return latency;
}

static void assert_dsp_output(float *actual[2], float *reference[2]) {
  for (int channel = 0; channel < 2; ++channel) {
    double energy = 0.0;
    for (unsigned long frame = 0; frame < FRAMES; ++frame) {
      assert_close(actual[channel][frame], reference[channel][frame]);
      energy += (double)actual[channel][frame] * actual[channel][frame];
    }
    assert(energy > 0.001 && energy < FRAMES);
  }
}

static void test_dsp_lifecycle(const LADSPA_Descriptor *descriptor,
                               struct dsp_ports ports, float *input[2],
                               float *first[2], float *second[2],
                               unsigned long rate) {
  LADSPA_Handle handle = descriptor->instantiate(descriptor, rate);
  assert(handle != NULL);
  float first_latency = NAN;
  float second_latency = NAN;

  connect_dsp(descriptor, handle, ports, input, first, &first_latency);
  descriptor->activate(handle);
  run_dsp(descriptor, handle, ports, input, first, &first_latency, 256);
  descriptor->deactivate(handle);

  connect_dsp(descriptor, handle, ports, input, second, &second_latency);
  descriptor->activate(handle);
  run_dsp(descriptor, handle, ports, input, second, &second_latency, 256);
  descriptor->deactivate(handle);
  descriptor->cleanup(handle);

  assert(first_latency == (float)expected_drc_delay(rate));
  assert(second_latency == (float)expected_drc_delay(rate));
  assert_dsp_output(second, first);
}

static float expected_speaker_gain(int percent) {
  if (percent <= 0) return 0.0f;
  if (percent > 100) percent = 100;
  int decibels_cent = redrix_speaker_curve_db_centibel[percent];
  if (decibels_cent > 0) decibels_cent = 0;
  return powf(10.0f, (float)decibels_cent / 2000.0f);
}

static void connect_speaker(const LADSPA_Descriptor *descriptor,
                            LADSPA_Handle handle, struct speaker_ports ports,
                            float *input[2], float *output[2],
                            float *volume_left, float *volume_right) {
  descriptor->connect_port(handle, ports.audio.input_left, input[0]);
  descriptor->connect_port(handle, ports.audio.input_right, input[1]);
  descriptor->connect_port(handle, ports.audio.output_left, output[0]);
  descriptor->connect_port(handle, ports.audio.output_right, output[1]);
  descriptor->connect_port(handle, ports.volume_left, volume_left);
  descriptor->connect_port(handle, ports.volume_right, volume_right);
}

static void run_speaker(const LADSPA_Descriptor *descriptor, LADSPA_Handle handle,
                        struct speaker_ports ports, float *input[2],
                        float *output[2], float *volume_left,
                        float *volume_right, unsigned long offset,
                        unsigned long frames) {
  float *input_at_offset[2] = { input[0] + offset, input[1] + offset };
  float *output_at_offset[2] = { output[0] + offset, output[1] + offset };
  connect_speaker(descriptor, handle, ports, input_at_offset, output_at_offset,
                  volume_left, volume_right);
  descriptor->run(handle, frames);
}

static float speaker_settled_gain(const LADSPA_Descriptor *descriptor,
                                  struct speaker_ports ports,
                                  float control) {
  float input_left[11];
  float input_right[11];
  float output_left[11] = { 0 };
  float output_right[11] = { 0 };
  float *input[2] = { input_left, input_right };
  float *output[2] = { output_left, output_right };
  for (unsigned long frame = 0; frame < 11; ++frame) {
    input_left[frame] = 1.0f;
    input_right[frame] = 1.0f;
  }

  LADSPA_Handle handle = descriptor->instantiate(descriptor, 1000);
  assert(handle != NULL);
  connect_speaker(descriptor, handle, ports, input, output, &control, &control);
  descriptor->activate(handle);
  descriptor->run(handle, 11);
  descriptor->deactivate(handle);
  descriptor->cleanup(handle);
  assert_close(output_left[0], 0.0f);
  assert_close(output_left[10], output_right[10]);
  return output_left[10];
}

static void test_speaker_curve(const LADSPA_Descriptor *descriptor,
                               struct speaker_ports ports) {
  enum { rate = 48000, startup_frames = 480, frames = startup_frames + 1 };
  float input_left[frames];
  float input_right[frames];
  float output_left[frames];
  float output_right[frames];
  float *input[2] = { input_left, input_right };
  float *output[2] = { output_left, output_right };
  for (unsigned long frame = 0; frame < (unsigned long)frames; ++frame) {
    input_left[frame] = 1.0f;
    input_right[frame] = 1.0f;
  }

  for (int percent = 0; percent <= 100; ++percent) {
    float control = (float)percent;
    LADSPA_Handle handle = descriptor->instantiate(descriptor, rate);
    assert(handle != NULL);
    connect_speaker(descriptor, handle, ports, input, output, &control, &control);
    descriptor->activate(handle);
    descriptor->run(handle, frames);
    descriptor->deactivate(handle);
    descriptor->cleanup(handle);

    const float expected = expected_speaker_gain(percent);
    assert_close(output_left[0], 0.0f);
    assert_close(output_right[0], 0.0f);
    assert_close(output_left[startup_frames], expected);
    assert_close(output_right[startup_frames], expected);
  }

  assert_close(speaker_settled_gain(descriptor, ports, 50.49f),
               expected_speaker_gain(50));
  assert_close(speaker_settled_gain(descriptor, ports, 50.50f),
               expected_speaker_gain(51));
  assert_close(speaker_settled_gain(descriptor, ports, 1000.0f),
               expected_speaker_gain(100));
  assert_close(speaker_settled_gain(descriptor, ports, -1.0f), 0.0f);
  assert_close(speaker_settled_gain(descriptor, ports, NAN), 0.0f);
  assert_close(speaker_settled_gain(descriptor, ports, INFINITY), 0.0f);
}

static void test_speaker_ramps(const LADSPA_Descriptor *descriptor,
                               struct speaker_ports ports) {
  enum { rate = 1000, frames = 700 };
  float input_left[frames];
  float input_right[frames];
  float output_left[frames] = { 0 };
  float output_right[frames] = { 0 };
  float *input[2] = { input_left, input_right };
  float *output[2] = { output_left, output_right };
  for (unsigned long frame = 0; frame < (unsigned long)frames; ++frame) {
    input_left[frame] = 1.0f;
    input_right[frame] = 1.0f;
  }

  const float gain_50 = expected_speaker_gain(50);
  const float gain_75 = expected_speaker_gain(75);
  const float gain_100 = expected_speaker_gain(100);
  float left_control = 100.0f;
  float right_control = 100.0f;
  LADSPA_Handle handle = descriptor->instantiate(descriptor, rate);
  assert(handle != NULL);
  connect_speaker(descriptor, handle, ports, input, output, &left_control,
                  &right_control);
  descriptor->activate(handle);

  unsigned long offset = 0;
  run_speaker(descriptor, handle, ports, input, output, &left_control,
              &right_control, offset, 3);
  assert_close(output_left[0], 0.0f);
  assert_close(output_left[1], gain_100 / 10.0f);
  assert_close(output_left[2], 2.0f * gain_100 / 10.0f);
  offset += 3;

  /* An unchanged target continues the original ten-sample startup ramp. */
  run_speaker(descriptor, handle, ports, input, output, &left_control,
              &right_control, offset, 2);
  assert_close(output_left[offset], 3.0f * gain_100 / 10.0f);
  assert_close(output_left[offset + 1], 4.0f * gain_100 / 10.0f);
  offset += 2;
  run_speaker(descriptor, handle, ports, input, output, &left_control,
              &right_control, offset, 5);
  offset += 5;

  left_control = 50.0f;
  run_speaker(descriptor, handle, ports, input, output, &left_control,
              &right_control, offset, 20);
  for (unsigned long frame = 0; frame < 20; ++frame) {
    const float expected = gain_100 +
        (float)frame * (gain_50 - gain_100) / 100.0f;
    assert_close(output_left[offset + frame], expected);
    assert_close(output_right[offset + frame], gain_100);
  }
  const float interrupted_start = gain_100 +
      20.0f * (gain_50 - gain_100) / 100.0f;
  offset += 20;

  /* A new target begins from the current sample-domain gain, not the old one. */
  left_control = 75.0f;
  run_speaker(descriptor, handle, ports, input, output, &left_control,
              &right_control, offset, 2);
  assert_close(output_left[offset], interrupted_start);
  assert_close(output_left[offset + 1], interrupted_start +
               (gain_75 - interrupted_start) / 100.0f);
  assert_close(output_right[offset], gain_100);
  assert_close(output_right[offset + 1], gain_100);
  descriptor->deactivate(handle);
  descriptor->cleanup(handle);

  left_control = 100.0f;
  right_control = 100.0f;
  handle = descriptor->instantiate(descriptor, rate);
  assert(handle != NULL);
  connect_speaker(descriptor, handle, ports, input, output, &left_control,
                  &right_control);
  descriptor->activate(handle);
  run_speaker(descriptor, handle, ports, input, output, &left_control,
              &right_control, 0, 10);
  offset = 10;

  left_control = 0.0f;
  run_speaker(descriptor, handle, ports, input, output, &left_control,
              &right_control, offset, 101);
  for (unsigned long frame = 0; frame <= 100; ++frame) {
    assert_close(output_left[offset + frame],
                 gain_100 - (float)frame * gain_100 / 100.0f);
    assert_close(output_right[offset + frame], gain_100);
  }
  offset += 101;

  left_control = 100.0f;
  run_speaker(descriptor, handle, ports, input, output, &left_control,
              &right_control, offset, 501);
  for (unsigned long frame = 0; frame <= 500; ++frame) {
    assert_close(output_left[offset + frame],
                 (float)frame * gain_100 / 500.0f);
    assert_close(output_right[offset + frame], gain_100);
  }
  descriptor->deactivate(handle);
  descriptor->cleanup(handle);
}

static void run_mic(const LADSPA_Descriptor *descriptor, LADSPA_Handle handle,
                    struct mic_ports ports, float **input, float **output,
                    unsigned long quantum) {
  for (unsigned long offset = 0; offset < FRAMES; offset += quantum) {
    unsigned long count = FRAMES - offset;
    if (count > quantum) count = quantum;
    descriptor->connect_port(handle, ports.audio.input_left, input[0] + offset);
    descriptor->connect_port(handle, ports.audio.input_right, input[1] + offset);
    descriptor->connect_port(handle, ports.audio.output_left, output[0] + offset);
    descriptor->connect_port(handle, ports.audio.output_right, output[1] + offset);
    descriptor->run(handle, count);
  }
}

static void test_mic_apm(const LADSPA_Descriptor *descriptor,
                         struct mic_ports ports) {
  float *input[2], *reference[2], *output[2];
  for (int channel = 0; channel < 2; ++channel) {
    input[channel] = calloc(FRAMES, sizeof(float));
    reference[channel] = calloc(FRAMES, sizeof(float));
    output[channel] = calloc(FRAMES, sizeof(float));
    assert(input[channel] && reference[channel] && output[channel]);
    for (unsigned long i = 0; i < FRAMES; ++i) {
      const float phase = 2 * 3.14159265358979323846f * (float)i / 48000;
      input[channel][i] = 0.15f * (1 + sinf(7 * phase)) *
          (sinf((channel ? 230 : 170) * phase) + 0.3f * sinf(610 * phase));
    }
  }
  float left = 100, right = 100, latency = -1;
  LADSPA_Handle handle = descriptor->instantiate(descriptor, 48000);
  assert(handle);
  assert(descriptor->instantiate(descriptor, 44100) == NULL);
  descriptor->connect_port(handle, ports.volume_left, &left);
  descriptor->connect_port(handle, ports.volume_right, &right);
  descriptor->connect_port(handle, ports.latency, &latency);
  descriptor->activate(handle);
  run_mic(descriptor, handle, ports, input, reference, 256);
  assert(latency == 480);
  double energy = 0;
  for (int channel = 0; channel < 2; ++channel)
    for (unsigned long i = 0; i < FRAMES; ++i) {
      assert(isfinite(reference[channel][i]));
      assert(fabsf(reference[channel][i]) <= 1.0f);
      if (i < 480) assert(reference[channel][i] == 0);
      energy += reference[channel][i] * reference[channel][i];
    }
  assert(energy > 1.0); // A broken/missing processor must not pass by silencing.
  const unsigned long quanta[] = {1, 31, 480, 2049, FRAMES};
  for (unsigned long q = 0; q < sizeof(quanta) / sizeof(*quanta); ++q) {
    descriptor->deactivate(handle);
    descriptor->activate(handle);
    run_mic(descriptor, handle, ports, input, output, quanta[q]);
    for (int channel = 0; channel < 2; ++channel)
      for (unsigned long i = 0; i < FRAMES; ++i)
        assert_close(output[channel][i], reference[channel][i]);
  }
  left = 50;
  right = 75;
  descriptor->deactivate(handle);
  descriptor->activate(handle);
  run_mic(descriptor, handle, ports, input, output, 113);
  for (unsigned long i = 0; i < FRAMES; ++i) {
    assert_close(output[0][i], reference[0][i] * 0.1f);
    assert_close(output[1][i], reference[1][i] * sqrtf(0.1f));
  }
  // Muting must silence even the already processed, buffered output.
  left = 0;
  right = NAN;
  run_mic(descriptor, handle, ports, input, output, 31);
  for (int channel = 0; channel < 2; ++channel)
    for (unsigned long i = 0; i < FRAMES; ++i) assert(output[channel][i] == 0);
  left = 1000;
  right = 100;
  descriptor->deactivate(handle);
  descriptor->activate(handle);
  for (int channel = 0; channel < 2; ++channel)
    memcpy(output[channel], input[channel], FRAMES * sizeof(float));
  run_mic(descriptor, handle, ports, output, output, 8192);
  for (int channel = 0; channel < 2; ++channel)
    for (unsigned long i = 0; i < FRAMES; ++i)
      assert_close(output[channel][i], reference[channel][i]);
  descriptor->deactivate(handle);
  descriptor->cleanup(handle);
  for (int channel = 0; channel < 2; ++channel) {
    free(input[channel]);
    free(reference[channel]);
    free(output[channel]);
  }
  puts("PASS: speech APM bounded output, post-AGC volume, buffered mute, block sizes and lifecycle");
}

static void test_mic_noise_suppression(const LADSPA_Descriptor *descriptor,
                                       struct mic_ports ports) {
  enum { BLOCK = 480, BLOCKS = 600, WARMUP = 300 };
  float input[2][BLOCK], output[2][BLOCK];
  float volume = 100;
  LADSPA_Handle handle = descriptor->instantiate(descriptor, 48000);
  assert(handle);
  descriptor->connect_port(handle, ports.audio.input_left, input[0]);
  descriptor->connect_port(handle, ports.audio.input_right, input[1]);
  descriptor->connect_port(handle, ports.audio.output_left, output[0]);
  descriptor->connect_port(handle, ports.audio.output_right, output[1]);
  descriptor->connect_port(handle, ports.volume_left, &volume);
  descriptor->connect_port(handle, ports.volume_right, &volume);
  descriptor->activate(handle);
  uint32_t random_state = 719;
  double input_energy = 0, output_energy[2] = {0, 0};
  for (unsigned int block = 0; block < BLOCKS; ++block) {
    for (unsigned int frame = 0; frame < BLOCK; ++frame) {
      random_state = random_state * UINT32_C(1664525) + UINT32_C(1013904223);
      const float noise = (float)(random_state >> 8) / 16777215.0f * 0.006f - 0.003f;
      input[0][frame] = input[1][frame] = noise;
      if (block >= WARMUP) input_energy += (double)noise * noise;
    }
    descriptor->run(handle, BLOCK);
    if (block >= WARMUP)
      for (unsigned int channel = 0; channel < 2; ++channel)
        for (unsigned int frame = 0; frame < BLOCK; ++frame) {
          const float value = output[channel][frame];
          assert(isfinite(value));
          output_energy[channel] += (double)value * value;
        }
  }
  descriptor->deactivate(handle);
  descriptor->cleanup(handle);
  // Require at least 6 dB attenuation versus the +20 dB compensated input,
  // not a particular WebRTC release's adaptive output. The separate voiced
  // test rejects a processor that merely silences everything.
  const double compensated_energy = input_energy * 100;
  for (unsigned int channel = 0; channel < 2; ++channel)
    assert(output_energy[channel] < compensated_energy * 0.25);
  puts("PASS: microphone suppresses stationary noise after adaptation");
}

int main(int argc, char **argv) {
  assert(argc == 2);
  void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) {
    fprintf(stderr, "%s\n", dlerror());
    return 1;
  }
  LADSPA_Descriptor_Function entry =
      (LADSPA_Descriptor_Function)dlsym(library, "ladspa_descriptor");
  assert(entry != NULL);

  const LADSPA_Descriptor *dsp =
      require_descriptor(entry, 0, "redrix_cras_dsp");
  const LADSPA_Descriptor *speaker =
      require_descriptor(entry, 1, "redrix_speaker_gain");
  const LADSPA_Descriptor *mic =
      require_descriptor(entry, 2, "redrix_mic_apm");
  assert(entry(3) == NULL);

  struct dsp_ports dsp_ports = {
    .audio = find_stereo_ports(dsp),
    .latency = find_port(dsp, "latency",
                         LADSPA_PORT_OUTPUT | LADSPA_PORT_CONTROL),
  };
  const LADSPA_PortRangeHint *latency_hint =
      &dsp->PortRangeHints[dsp_ports.latency];
  assert(latency_hint->HintDescriptor & LADSPA_HINT_BOUNDED_BELOW);
  assert(latency_hint->LowerBound == 0.0f);

  struct speaker_ports speaker_ports = {
    .audio = find_stereo_ports(speaker),
    .volume_left = find_port(speaker, "Volume Left",
                             LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL),
    .volume_right = find_port(speaker, "Volume Right",
                              LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL),
  };
  assert_percent_range(speaker, speaker_ports.volume_left);
  assert_percent_range(speaker, speaker_ports.volume_right);

  struct mic_ports mic_ports = {
    .audio = find_stereo_ports(mic),
    .volume_left = find_port(mic, "Volume Left", LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL),
    .volume_right = find_port(mic, "Volume Right", LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL),
    .latency = find_port(mic, "latency", LADSPA_PORT_OUTPUT | LADSPA_PORT_CONTROL),
  };
  assert_percent_range(mic, mic_ports.volume_left);
  assert_percent_range(mic, mic_ports.volume_right);

  const unsigned long rates[] = { 44100, 48000, 96000 };
  const unsigned long quanta[] = { 1, 31, 256, 2048, 2049, 8192, FRAMES };
  float *input[2];
  float *output[2];
  float *reference[2];
  for (int channel = 0; channel < 2; ++channel) {
    input[channel] = calloc(FRAMES, sizeof(*input[channel]));
    output[channel] = calloc(FRAMES, sizeof(*output[channel]));
    reference[channel] = calloc(FRAMES, sizeof(*reference[channel]));
    assert(input[channel] && output[channel] && reference[channel]);
  }

  for (unsigned long rate_index = 0;
       rate_index < sizeof(rates) / sizeof(*rates); ++rate_index) {
    const unsigned long rate = rates[rate_index];
    for (int channel = 0; channel < 2; ++channel)
      for (unsigned long frame = 0; frame < FRAMES; ++frame)
        input[channel][frame] = 0.1f * sinf(2.0f * 3.14159265358979323846f *
            (channel ? 1700.0f : 440.0f) * (float)frame / (float)rate);

    const float reference_latency = process_dsp(
        dsp, dsp_ports, input, reference, 256, rate);
    assert(reference_latency == (float)expected_drc_delay(rate));
    for (unsigned long quantum_index = 0;
         quantum_index < sizeof(quanta) / sizeof(*quanta); ++quantum_index) {
      const float latency = process_dsp(dsp, dsp_ports, input, output,
                                        quanta[quantum_index], rate);
      assert(latency == (float)expected_drc_delay(rate));
      assert_dsp_output(output, reference);
    }

    test_dsp_lifecycle(dsp, dsp_ports, input, reference, output, rate);
    const float in_place_latency = process_dsp(dsp, dsp_ports, input, input,
                                               8192, rate);
    assert(in_place_latency == (float)expected_drc_delay(rate));
    assert_dsp_output(input, reference);
    printf("PASS: %lu Hz; DSP block sizes, delay, lifecycle, cleanup, in-place\n",
           rate);
  }

  test_speaker_curve(speaker, speaker_ports);
  test_speaker_ramps(speaker, speaker_ports);
  puts("PASS: ChromeOS speaker curve and linear ramps");
  test_mic_apm(mic, mic_ports);
  test_mic_noise_suppression(mic, mic_ports);

  for (int channel = 0; channel < 2; ++channel) {
    free(input[channel]);
    free(output[channel]);
    free(reference[channel]);
  }
  dlclose(library);
  return 0;
}
