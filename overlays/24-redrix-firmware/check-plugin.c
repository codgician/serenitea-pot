/* Exercise the public LADSPA ABI without a running audio server. */
#include <assert.h>
#include <dlfcn.h>
#include <ladspa.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define FRAMES 16385

static void process(const LADSPA_Descriptor *d, float *input[2], float *output[2],
                    unsigned long quantum, unsigned long rate) {
  LADSPA_Handle h = d->instantiate(d, rate);
  assert(h != NULL);
  if (d->activate) d->activate(h);
  for (unsigned long offset = 0; offset < FRAMES;) {
    unsigned long count = FRAMES - offset;
    if (count > quantum) count = quantum;
    for (int channel = 0; channel < 2; ++channel) {
      d->connect_port(h, channel, input[channel] + offset);
      d->connect_port(h, channel + 2, output[channel] + offset);
    }
    d->run(h, count);
    offset += count;
  }
  d->run(h, 0);
  if (d->deactivate) d->deactivate(h);
  /* Hosts may reactivate the same instance, rather than instantiate again. */
  if (d->activate) d->activate(h);
  float scratch[4] = {0};
  for (int p = 0; p < 4; ++p) d->connect_port(h, p, &scratch[p]);
  d->run(h, 1);
  if (d->deactivate) d->deactivate(h);
  d->cleanup(h);
}

int main(int argc, char **argv) {
  assert(argc == 2);
  void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) { fprintf(stderr, "%s\n", dlerror()); return 1; }
  LADSPA_Descriptor_Function entry = (LADSPA_Descriptor_Function)dlsym(library, "ladspa_descriptor");
  assert(entry != NULL);
  const LADSPA_Descriptor *d = entry(0);
  assert(d && !entry(1));
  /* Cleanup is mandatory; deactivation must never destroy an instance. */
  assert(d->cleanup != NULL);
  assert(d->instantiate && d->connect_port && d->run);
  assert(d->PortCount == 4);
  const unsigned long rates[] = {44100, 48000, 96000};
  const unsigned long quanta[] = {1, 31, 256, 2048, 2049, 8192, FRAMES};
  float *input[2], *output[2], *reference[2];
  for (int c = 0; c < 2; ++c) {
    input[c] = calloc(FRAMES, sizeof(float));
    output[c] = calloc(FRAMES, sizeof(float));
    reference[c] = calloc(FRAMES, sizeof(float));
    assert(input[c] && output[c] && reference[c]);
  }
  for (unsigned int r = 0; r < sizeof(rates) / sizeof(*rates); ++r) {
    for (int c = 0; c < 2; ++c)
      for (int i = 0; i < FRAMES; ++i)
        input[c][i] = 0.1f * sinf(2.0f * 3.14159265358979323846f * (c ? 1700 : 440) * i / rates[r]);
    process(d, input, reference, 256, rates[r]);
    for (unsigned int q = 0; q < sizeof(quanta) / sizeof(*quanta); ++q) {
      process(d, input, output, quanta[q], rates[r]);
      for (int c = 0; c < 2; ++c) {
        double energy = 0;
        for (int i = 0; i < FRAMES; ++i) {
          assert(isfinite(output[c][i]));
          assert(fabsf(output[c][i] - reference[c][i]) < 1e-5f);
          energy += (double)output[c][i] * output[c][i];
        }
        assert(energy > 0.001 && energy < FRAMES);
      }
    }
    /* LADSPA permits in-place operation, which PipeWire can choose. */
    process(d, input, input, 8192, rates[r]);
    for (int c = 0; c < 2; ++c)
      for (int i = 0; i < FRAMES; ++i)
        assert(fabsf(input[c][i] - reference[c][i]) < 1e-5f);
    printf("PASS: %lu Hz; block-size equivalence, lifecycle, cleanup, in-place\n", rates[r]);
  }
  for (int c = 0; c < 2; ++c) { free(input[c]); free(output[c]); free(reference[c]); }
  dlclose(library);
  return 0;
}
