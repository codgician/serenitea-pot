#include <ladspa.h>
#include <math.h>
#include <stdlib.h>

#include "drc.h"
#include "eq2.h"
#include "redrix-speaker-curve.h"

enum redrix_cras_ports {
  REDRIX_CRAS_INPUT_LEFT,
  REDRIX_CRAS_INPUT_RIGHT,
  REDRIX_CRAS_OUTPUT_LEFT,
  REDRIX_CRAS_OUTPUT_RIGHT,
  REDRIX_CRAS_LATENCY,
  REDRIX_CRAS_PORT_COUNT,
};

struct redrix_instance {
  LADSPA_Data *ports[REDRIX_CRAS_PORT_COUNT];
  unsigned long sample_rate;
  int active;
  int processed;
  struct drc *drc;
  struct eq2 *eq;
};

/* Recovery 16733.54.0: /etc/cras/redrix/dsp.ini, in original stage order.
 * CRAS interprets high-pass Q as resonance; its gain field is unused.
 */
static const struct {
  enum biquad_type type;
  float frequency;
  float q;
  float gain[2];
} eq_bands[] = {
  { BQ_PEAKING,   400,   4, { -3,  -3 } },
  { BQ_PEAKING,   610,   3, { -8,  -8 } },
  { BQ_HIGHSHELF, 1200,  1, { -4,  -7 } },
  { BQ_PEAKING,   2200,  3, { -3,  -3 } },
  { BQ_PEAKING,   10500, 2, { -10, -7 } },
  { BQ_PEAKING,   3853,  2, { -5,  -5 } },
  { BQ_PEAKING,   5500,  3, { -3,  -3 } },
  { BQ_HIGHPASS,  150,   0, {  0,   0 } },
};

static void destroy_cras_dsp(struct redrix_instance *instance) {
  if (instance->eq) eq2_free(instance->eq);
  if (instance->drc) drc_free(instance->drc);
  instance->eq = NULL;
  instance->drc = NULL;
}

static int initialize_cras_dsp(struct redrix_instance *instance) {
  struct drc *drc = drc_new((float)instance->sample_rate);
  if (!drc) return 0;

  drc->emphasis_disabled = 1;
  for (int band = 0; band < 3; ++band) {
    drc_set_param(drc, band, PARAM_ENABLED, 1);
    drc_set_param(drc, band, PARAM_THRESHOLD, -24);
    drc_set_param(drc, band, PARAM_KNEE, band == 0 ? 30 : 32);
    drc_set_param(drc, band, PARAM_RATIO, band == 0 ? 12 : 15);
    drc_set_param(drc, band, PARAM_ATTACK, band == 0 ? 0.001f : 0.003f);
    drc_set_param(drc, band, PARAM_RELEASE, 0.25f);
    drc_set_param(drc, band, PARAM_POST_GAIN, band);
  }
  drc_set_param(drc, 1, PARAM_CROSSOVER_LOWER_FREQ,
                200.0 / (instance->sample_rate / 2.0));
  drc_set_param(drc, 2, PARAM_CROSSOVER_LOWER_FREQ,
                2000.0 / (instance->sample_rate / 2.0));
  drc_init(drc);

  struct eq2 *eq = eq2_new();
  if (!eq) {
    drc_free(drc);
    return 0;
  }
  for (unsigned int band = 0; band < sizeof(eq_bands) / sizeof(eq_bands[0]);
       ++band) {
    const float frequency = eq_bands[band].frequency /
                            (instance->sample_rate / 2.0);
    for (int channel = 0; channel < 2; ++channel) {
      if (eq2_append_biquad(eq, channel, eq_bands[band].type, frequency,
                            eq_bands[band].q, eq_bands[band].gain[channel])) {
        eq2_free(eq);
        drc_free(drc);
        return 0;
      }
    }
  }

  instance->drc = drc;
  instance->eq = eq;
  return 1;
}

/* The upstream DRC and EQ retain delay and filter history.  Rebuild them at
 * activation, outside the audio callback, so each stream start is clean. */
static int reset_cras_dsp(struct redrix_instance *instance) {
  destroy_cras_dsp(instance);
  return initialize_cras_dsp(instance);
}

static LADSPA_Handle cras_instantiate(const LADSPA_Descriptor *descriptor,
                                      unsigned long sample_rate) {
  (void)descriptor;
  if (!sample_rate) return NULL;

  struct redrix_instance *instance = calloc(1, sizeof(*instance));
  if (!instance) return NULL;
  instance->sample_rate = sample_rate;
  if (!initialize_cras_dsp(instance)) {
    destroy_cras_dsp(instance);
    free(instance);
    return NULL;
  }
  return instance;
}

static void cras_connect_port(LADSPA_Handle handle, unsigned long port,
                              LADSPA_Data *data) {
  struct redrix_instance *instance = handle;
  if (port < REDRIX_CRAS_PORT_COUNT) instance->ports[port] = data;
  if (port == REDRIX_CRAS_LATENCY && data && instance->drc)
    *data = (LADSPA_Data)instance->drc->kernel[0].last_pre_delay_frames;
}

static void silence(float *output, unsigned long frames) {
  if (!output) return;
  for (unsigned long frame = 0; frame < frames; ++frame) output[frame] = 0.0f;
}

static void cras_activate(LADSPA_Handle handle) {
  struct redrix_instance *instance = handle;
  instance->active = (instance->drc && instance->eq && !instance->processed) ||
      reset_cras_dsp(instance);
  instance->processed = 0;
}

static void cras_deactivate(LADSPA_Handle handle) {
  ((struct redrix_instance *)handle)->active = 0;
}

static void cras_run(LADSPA_Handle handle, unsigned long frames) {
  struct redrix_instance *instance = handle;
  if (instance->ports[REDRIX_CRAS_LATENCY]) {
    *instance->ports[REDRIX_CRAS_LATENCY] = instance->drc
        ? (LADSPA_Data)instance->drc->kernel[0].last_pre_delay_frames
        : 0.0f;
  }

  if (!instance->active || !instance->drc || !instance->eq ||
      !instance->ports[REDRIX_CRAS_INPUT_LEFT] ||
      !instance->ports[REDRIX_CRAS_INPUT_RIGHT] ||
      !instance->ports[REDRIX_CRAS_OUTPUT_LEFT] ||
      !instance->ports[REDRIX_CRAS_OUTPUT_RIGHT]) {
    silence(instance->ports[REDRIX_CRAS_OUTPUT_LEFT], frames);
    silence(instance->ports[REDRIX_CRAS_OUTPUT_RIGHT], frames);
    return;
  }

  for (unsigned long offset = 0; offset < frames;) {
    unsigned long count = frames - offset;
    if (count > DRC_PROCESS_MAX_FRAMES) count = DRC_PROCESS_MAX_FRAMES;
    float *channels[2] = {
      instance->ports[REDRIX_CRAS_OUTPUT_LEFT] + offset,
      instance->ports[REDRIX_CRAS_OUTPUT_RIGHT] + offset,
    };
    if (channels[0] != instance->ports[REDRIX_CRAS_INPUT_LEFT] + offset ||
        channels[1] != instance->ports[REDRIX_CRAS_INPUT_RIGHT] + offset) {
      for (unsigned long frame = 0; frame < count; ++frame) {
        const float left = instance->ports[REDRIX_CRAS_INPUT_LEFT][offset + frame];
        const float right = instance->ports[REDRIX_CRAS_INPUT_RIGHT][offset + frame];
        channels[0][frame] = left;
        channels[1][frame] = right;
      }
    }
    drc_process(instance->drc, channels, (int)count);
    eq2_process(instance->eq, channels[0], channels[1], (int)count);
    instance->processed = 1;
    offset += count;
  }
}

static void cras_cleanup(LADSPA_Handle handle) {
  struct redrix_instance *instance = handle;
  destroy_cras_dsp(instance);
  free(instance);
}

static const LADSPA_PortDescriptor cras_port_descriptors[] = {
  LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_OUTPUT | LADSPA_PORT_CONTROL,
};
static const char *cras_port_names[] = {
  "Input Left", "Input Right", "Output Left", "Output Right", "latency",
};
static const LADSPA_PortRangeHint cras_port_hints[] = {
  { 0, 0.0f, 0.0f },
  { 0, 0.0f, 0.0f },
  { 0, 0.0f, 0.0f },
  { 0, 0.0f, 0.0f },
  { LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE, 0.0f, 1024.0f },
};

static const LADSPA_Descriptor cras_descriptor = {
  .UniqueID = 0x726478,
  .Label = "redrix_cras_dsp",
  .Properties = LADSPA_PROPERTY_HARD_RT_CAPABLE,
  .Name = "Redrix ChromeOS CRAS DSP",
  .Maker = "serenitea-pot",
  .Copyright = "BSD-3-Clause",
  .PortCount = REDRIX_CRAS_PORT_COUNT,
  .PortDescriptors = cras_port_descriptors,
  .PortNames = cras_port_names,
  .PortRangeHints = cras_port_hints,
  .instantiate = cras_instantiate,
  .connect_port = cras_connect_port,
  .activate = cras_activate,
  .run = cras_run,
  .deactivate = cras_deactivate,
  .cleanup = cras_cleanup,
};

enum redrix_speaker_ports {
  REDRIX_SPEAKER_INPUT_LEFT,
  REDRIX_SPEAKER_INPUT_RIGHT,
  REDRIX_SPEAKER_OUTPUT_LEFT,
  REDRIX_SPEAKER_OUTPUT_RIGHT,
  REDRIX_SPEAKER_VOLUME_LEFT,
  REDRIX_SPEAKER_VOLUME_RIGHT,
  REDRIX_SPEAKER_PORT_COUNT,
};

struct redrix_speaker_instance {
  LADSPA_Data *ports[REDRIX_SPEAKER_PORT_COUNT];
  unsigned long sample_rate;
  float current_gain[2];
  float target_gain[2];
  float gain_step[2];
  unsigned long remaining_frames[2];
  int target_percent[2];
  int active;
};

static unsigned long frames_for_milliseconds(unsigned long sample_rate,
                                             unsigned long milliseconds) {
  unsigned long frames = (sample_rate / 1000) * milliseconds +
      ((sample_rate % 1000) * milliseconds) / 1000;
  return frames ? frames : 1;
}

/* PipeWire's PA conversion can land on either side of an integer boundary.
 * Round to the nearest ChromeOS curve position before indexing it. */
static int speaker_percent_from_control(LADSPA_Data value) {
  if (!isfinite(value) || value <= 0.0f) return 0;
  if (value >= 100.0f) return 100;
  return (int)floorf(value + 0.5f);
}

static float speaker_gain_for_percent(int percent) {
  if (percent <= 0) return 0.0f;
  if (percent > 100) percent = 100;

  int decibels_cent = redrix_speaker_curve_db_centibel[percent];
  if (decibels_cent > 0) decibels_cent = 0;
  return powf(10.0f, (float)decibels_cent / 2000.0f);
}

static void speaker_set_target(struct redrix_speaker_instance *instance,
                               unsigned int channel, int percent) {
  if (instance->target_percent[channel] == percent) return;

  const float target = speaker_gain_for_percent(percent);
  if (instance->target_percent[channel] >= 0 &&
      target == instance->target_gain[channel]) {
    instance->target_percent[channel] = percent;
    return;
  }

  unsigned long duration;
  if (instance->target_percent[channel] < 0)
    duration = frames_for_milliseconds(instance->sample_rate, 10);
  else if (percent == 0)
    duration = frames_for_milliseconds(instance->sample_rate, 100);
  else if (instance->target_gain[channel] == 0.0f)
    duration = frames_for_milliseconds(instance->sample_rate, 500);
  else
    duration = frames_for_milliseconds(instance->sample_rate, 100);

  instance->target_percent[channel] = percent;
  instance->target_gain[channel] = target;
  if (target == instance->current_gain[channel]) {
    instance->remaining_frames[channel] = 0;
    instance->gain_step[channel] = 0.0f;
    return;
  }
  instance->remaining_frames[channel] = duration;
  instance->gain_step[channel] =
      (target - instance->current_gain[channel]) / (float)duration;
}

static void advance_speaker_gain(struct redrix_speaker_instance *instance,
                                 unsigned int channel) {
  if (!instance->remaining_frames[channel]) return;

  instance->current_gain[channel] += instance->gain_step[channel];
  if (!--instance->remaining_frames[channel]) {
    instance->current_gain[channel] = instance->target_gain[channel];
    instance->gain_step[channel] = 0.0f;
  }
}

static LADSPA_Handle speaker_instantiate(const LADSPA_Descriptor *descriptor,
                                         unsigned long sample_rate) {
  (void)descriptor;
  if (!sample_rate) return NULL;

  struct redrix_speaker_instance *instance = calloc(1, sizeof(*instance));
  if (!instance) return NULL;
  instance->sample_rate = sample_rate;
  instance->target_percent[0] = -1;
  instance->target_percent[1] = -1;
  return instance;
}

static void speaker_connect_port(LADSPA_Handle handle, unsigned long port,
                                 LADSPA_Data *data) {
  if (port < REDRIX_SPEAKER_PORT_COUNT)
    ((struct redrix_speaker_instance *)handle)->ports[port] = data;
}

static void speaker_activate(LADSPA_Handle handle) {
  struct redrix_speaker_instance *instance = handle;
  for (unsigned int channel = 0; channel < 2; ++channel) {
    instance->current_gain[channel] = 0.0f;
    instance->target_gain[channel] = 0.0f;
    instance->gain_step[channel] = 0.0f;
    instance->remaining_frames[channel] = 0;
    instance->target_percent[channel] = -1;
  }
  instance->active = 1;
}

static void speaker_deactivate(LADSPA_Handle handle) {
  ((struct redrix_speaker_instance *)handle)->active = 0;
}

static void speaker_run(LADSPA_Handle handle, unsigned long frames) {
  struct redrix_speaker_instance *instance = handle;
  if (!instance->active || !instance->ports[REDRIX_SPEAKER_INPUT_LEFT] ||
      !instance->ports[REDRIX_SPEAKER_INPUT_RIGHT] ||
      !instance->ports[REDRIX_SPEAKER_OUTPUT_LEFT] ||
      !instance->ports[REDRIX_SPEAKER_OUTPUT_RIGHT]) {
    silence(instance->ports[REDRIX_SPEAKER_OUTPUT_LEFT], frames);
    silence(instance->ports[REDRIX_SPEAKER_OUTPUT_RIGHT], frames);
    return;
  }

  const LADSPA_Data left_control = instance->ports[REDRIX_SPEAKER_VOLUME_LEFT]
      ? *instance->ports[REDRIX_SPEAKER_VOLUME_LEFT] : 0.0f;
  const LADSPA_Data right_control = instance->ports[REDRIX_SPEAKER_VOLUME_RIGHT]
      ? *instance->ports[REDRIX_SPEAKER_VOLUME_RIGHT] : 0.0f;
  speaker_set_target(instance, 0, speaker_percent_from_control(left_control));
  speaker_set_target(instance, 1, speaker_percent_from_control(right_control));

  for (unsigned long frame = 0; frame < frames; ++frame) {
    const float left = instance->ports[REDRIX_SPEAKER_INPUT_LEFT][frame];
    const float right = instance->ports[REDRIX_SPEAKER_INPUT_RIGHT][frame];
    instance->ports[REDRIX_SPEAKER_OUTPUT_LEFT][frame] =
        left * instance->current_gain[0];
    instance->ports[REDRIX_SPEAKER_OUTPUT_RIGHT][frame] =
        right * instance->current_gain[1];
    advance_speaker_gain(instance, 0);
    advance_speaker_gain(instance, 1);
  }
}

static void speaker_cleanup(LADSPA_Handle handle) {
  free(handle);
}

static const LADSPA_PortDescriptor speaker_port_descriptors[] = {
  LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL,
  LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL,
};
static const char *speaker_port_names[] = {
  "Input Left", "Input Right", "Output Left", "Output Right",
  "Volume Left", "Volume Right",
};
static const LADSPA_PortRangeHint speaker_port_hints[] = {
  { 0, 0.0f, 0.0f },
  { 0, 0.0f, 0.0f },
  { 0, 0.0f, 0.0f },
  { 0, 0.0f, 0.0f },
  { LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE, 0.0f, 100.0f },
  { LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE, 0.0f, 100.0f },
};

static const LADSPA_Descriptor speaker_descriptor = {
  .UniqueID = 0x726479,
  .Label = "redrix_speaker_gain",
  .Properties = LADSPA_PROPERTY_HARD_RT_CAPABLE,
  .Name = "Redrix ChromeOS speaker gain",
  .Maker = "serenitea-pot",
  .Copyright = "BSD-3-Clause",
  .PortCount = REDRIX_SPEAKER_PORT_COUNT,
  .PortDescriptors = speaker_port_descriptors,
  .PortNames = speaker_port_names,
  .PortRangeHints = speaker_port_hints,
  .instantiate = speaker_instantiate,
  .connect_port = speaker_connect_port,
  .activate = speaker_activate,
  .run = speaker_run,
  .deactivate = speaker_deactivate,
  .cleanup = speaker_cleanup,
};

enum redrix_mic_ports {
  REDRIX_MIC_INPUT,
  REDRIX_MIC_OUTPUT,
  REDRIX_MIC_VOLUME,
  REDRIX_MIC_PORT_COUNT,
};

struct redrix_mic_instance {
  LADSPA_Data *ports[REDRIX_MIC_PORT_COUNT];
  LADSPA_Data cached_percent;
  float gain;
  int has_cached_gain;
  int active;
};

static LADSPA_Data mic_percent_from_control(LADSPA_Data value) {
  if (!isfinite(value) || value <= 0.0f) return 0.0f;
  return value > 100.0f ? 100.0f : value;
}

/* +20 dB corrects the microphone sensitivity.  CRAS's 0.4 dB/UI-percent
 * curve then reaches the requested +40 dB maximum at 100 percent. */
static float mic_gain_for_percent(LADSPA_Data percent) {
  if (percent <= 0.0f) return 0.0f;

  float decibels = 20.0f + 0.4f * (percent - 50.0f);
  if (decibels > 40.0f) decibels = 40.0f;
  return powf(10.0f, decibels / 20.0f);
}

static LADSPA_Handle mic_instantiate(const LADSPA_Descriptor *descriptor,
                                     unsigned long sample_rate) {
  (void)descriptor;
  (void)sample_rate;
  return calloc(1, sizeof(struct redrix_mic_instance));
}

static void mic_connect_port(LADSPA_Handle handle, unsigned long port,
                             LADSPA_Data *data) {
  if (port < REDRIX_MIC_PORT_COUNT)
    ((struct redrix_mic_instance *)handle)->ports[port] = data;
}

static void mic_activate(LADSPA_Handle handle) {
  struct redrix_mic_instance *instance = handle;
  instance->has_cached_gain = 0;
  instance->active = 1;
}

static void mic_deactivate(LADSPA_Handle handle) {
  ((struct redrix_mic_instance *)handle)->active = 0;
}

static void mic_run(LADSPA_Handle handle, unsigned long frames) {
  struct redrix_mic_instance *instance = handle;
  if (!instance->active || !instance->ports[REDRIX_MIC_INPUT] ||
      !instance->ports[REDRIX_MIC_OUTPUT]) {
    silence(instance->ports[REDRIX_MIC_OUTPUT], frames);
    return;
  }

  const LADSPA_Data percent = mic_percent_from_control(
      instance->ports[REDRIX_MIC_VOLUME] ? *instance->ports[REDRIX_MIC_VOLUME]
                                          : 0.0f);
  if (!instance->has_cached_gain || percent != instance->cached_percent) {
    instance->cached_percent = percent;
    instance->gain = mic_gain_for_percent(percent);
    instance->has_cached_gain = 1;
  }

  for (unsigned long frame = 0; frame < frames; ++frame)
    instance->ports[REDRIX_MIC_OUTPUT][frame] =
        instance->ports[REDRIX_MIC_INPUT][frame] * instance->gain;
}

static void mic_cleanup(LADSPA_Handle handle) {
  free(handle);
}

static const LADSPA_PortDescriptor mic_port_descriptors[] = {
  LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_INPUT | LADSPA_PORT_CONTROL,
};
static const char *mic_port_names[] = {
  "Input", "Output", "Volume",
};
static const LADSPA_PortRangeHint mic_port_hints[] = {
  { 0, 0.0f, 0.0f },
  { 0, 0.0f, 0.0f },
  { LADSPA_HINT_BOUNDED_BELOW | LADSPA_HINT_BOUNDED_ABOVE, 0.0f, 100.0f },
};

static const LADSPA_Descriptor mic_descriptor = {
  .UniqueID = 0x72647a,
  .Label = "redrix_mic_gain",
  .Properties = LADSPA_PROPERTY_HARD_RT_CAPABLE,
  .Name = "Redrix ChromeOS microphone gain",
  .Maker = "serenitea-pot",
  .Copyright = "BSD-3-Clause",
  .PortCount = REDRIX_MIC_PORT_COUNT,
  .PortDescriptors = mic_port_descriptors,
  .PortNames = mic_port_names,
  .PortRangeHints = mic_port_hints,
  .instantiate = mic_instantiate,
  .connect_port = mic_connect_port,
  .activate = mic_activate,
  .run = mic_run,
  .deactivate = mic_deactivate,
  .cleanup = mic_cleanup,
};

const LADSPA_Descriptor *ladspa_descriptor(unsigned long index) {
  switch (index) {
    case 0: return &cras_descriptor;
    case 1: return &speaker_descriptor;
    case 2: return &mic_descriptor;
    default: return NULL;
  }
}
