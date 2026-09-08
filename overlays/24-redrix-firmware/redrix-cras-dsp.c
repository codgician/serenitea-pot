#include <ladspa.h>
#include <stdlib.h>

#include "drc.h"
#include "eq2.h"

struct redrix_instance {
  LADSPA_Data *ports[4];
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

static LADSPA_Handle instantiate(const LADSPA_Descriptor *descriptor,
                                 unsigned long sample_rate) {
  (void)descriptor;
  struct redrix_instance *instance = calloc(1, sizeof(*instance));
  if (!instance) return NULL;

  instance->drc = drc_new((float)sample_rate);
  if (!instance->drc) {
    free(instance);
    return NULL;
  }
  instance->drc->emphasis_disabled = 1;

  for (int band = 0; band < 3; band++) {
    drc_set_param(instance->drc, band, PARAM_ENABLED, 1);
    drc_set_param(instance->drc, band, PARAM_THRESHOLD, -24);
    drc_set_param(instance->drc, band, PARAM_KNEE, band == 0 ? 30 : 32);
    drc_set_param(instance->drc, band, PARAM_RATIO, band == 0 ? 12 : 15);
    drc_set_param(instance->drc, band, PARAM_ATTACK, band == 0 ? 0.001 : 0.003);
    drc_set_param(instance->drc, band, PARAM_RELEASE, 0.25);
    drc_set_param(instance->drc, band, PARAM_POST_GAIN, band);
  }
  drc_set_param(instance->drc, 1, PARAM_CROSSOVER_LOWER_FREQ, 200.0 / (sample_rate / 2.0));
  drc_set_param(instance->drc, 2, PARAM_CROSSOVER_LOWER_FREQ, 2000.0 / (sample_rate / 2.0));
  drc_init(instance->drc);

  instance->eq = eq2_new();
  if (!instance->eq) {
    drc_free(instance->drc);
    free(instance);
    return NULL;
  }
  for (unsigned int band = 0; band < sizeof(eq_bands) / sizeof(eq_bands[0]); ++band) {
    float frequency = eq_bands[band].frequency / (sample_rate / 2.0);
    for (int channel = 0; channel < 2; ++channel) {
      eq2_append_biquad(instance->eq, channel, eq_bands[band].type,
                       frequency, eq_bands[band].q, eq_bands[band].gain[channel]);
    }
  }
  return instance;
}

static void connect_port(LADSPA_Handle handle, unsigned long port,
                         LADSPA_Data *data) {
  if (port < 4) ((struct redrix_instance *)handle)->ports[port] = data;
}

static void run(LADSPA_Handle handle, unsigned long frames) {
  struct redrix_instance *instance = handle;
  for (unsigned long offset = 0; offset < frames; ) {
    unsigned long count = frames - offset;
    if (count > DRC_PROCESS_MAX_FRAMES) count = DRC_PROCESS_MAX_FRAMES;
    float *channels[2] = {
      instance->ports[2] + offset,
      instance->ports[3] + offset,
    };
    if (channels[0] != instance->ports[0] + offset ||
        channels[1] != instance->ports[1] + offset) {
      for (unsigned long i = 0; i < count; i++) {
        const float left = instance->ports[0][offset + i];
        const float right = instance->ports[1][offset + i];
        channels[0][i] = left;
        channels[1][i] = right;
      }
    }
    drc_process(instance->drc, channels, (int)count);
    eq2_process(instance->eq, channels[0], channels[1], (int)count);
    offset += count;
  }
}

static void cleanup(LADSPA_Handle handle) {
  struct redrix_instance *instance = handle;
  eq2_free(instance->eq);
  drc_free(instance->drc);
  free(instance);
}

static const LADSPA_PortDescriptor ports[] = {
  LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_INPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO,
  LADSPA_PORT_OUTPUT | LADSPA_PORT_AUDIO,
};
static const char *port_names[] = { "Input Left", "Input Right", "Output Left", "Output Right" };
static const LADSPA_PortRangeHint hints[4] = {0};
/* Use designated fields: deactivate must never free the instance. */
static const LADSPA_Descriptor descriptor = {
  .UniqueID = 0x726478,
  .Label = "redrix_cras_dsp",
  .Properties = LADSPA_PROPERTY_HARD_RT_CAPABLE,
  .Name = "Redrix ChromeOS CRAS DSP",
  .Maker = "serenitea-pot",
  .Copyright = "BSD-3-Clause",
  .PortCount = 4,
  .PortDescriptors = ports,
  .PortNames = port_names,
  .PortRangeHints = hints,
  .instantiate = instantiate,
  .connect_port = connect_port,
  .run = run,
  .cleanup = cleanup,
};

const LADSPA_Descriptor *ladspa_descriptor(unsigned long index) {
  return index == 0 ? &descriptor : NULL;
}
