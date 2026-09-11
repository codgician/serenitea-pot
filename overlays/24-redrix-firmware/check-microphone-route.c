/* Open the installed UCM route against a four-channel file/null PCM, not hardware. */
#include <alsa/asoundlib.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void check(int result) {
  if (result < 0) {
    fprintf(stderr, "ALSA route check: %s\n", snd_strerror(result));
    exit(1);
  }
}

int main(int argc, char **argv) {
  assert(argc == 2);
  snd_config_t *profile, *route, *copy, *value, *config, *pcms;
  snd_input_t *input;
  long channels;
  check(snd_config_top(&profile));
  check(snd_input_stdio_open(&input, argv[1], "r"));
  check(snd_config_load(profile, input));
  snd_input_close(input);
  check(snd_config_search(profile, "SectionDevice.Mic1.Value.CaptureChannels", &value));
  check(snd_config_get_integer(value, &channels));
  assert(channels == 2);
  check(snd_config_search(profile, "LibraryConfig.mic.SubstiConfig.pcm.redrix_mic", &route));
  check(snd_config_copy(&copy, route));
  check(snd_config_search(copy, "slave.pcm", &value));
  check(snd_config_set_string(value, "reference_source"));

  FILE *samples = tmpfile();
  assert(samples);
  const int32_t frame[4] = {0x10000000, 0x20000000, -0x10000000, -0x20000000};
  for (int i = 0; i < 8192; ++i) assert(fwrite(frame, sizeof(frame), 1, samples) == 1);
  rewind(samples);
  char text[512];
  snprintf(text, sizeof(text),
      "pcm.null { type null }\n"
      "pcm.reference_source { type file slave.pcm null file /dev/null "
      "infile /proc/self/fd/%d format raw }\n", fileno(samples));
  check(snd_config_top(&config));
  check(snd_input_buffer_open(&input, text, -1));
  check(snd_config_load(config, input));
  snd_input_close(input);
  check(snd_config_search(config, "pcm", &pcms));
  check(snd_config_add(pcms, copy));

  snd_pcm_t *pcm;
  check(snd_pcm_open_lconf(&pcm, "redrix_mic", SND_PCM_STREAM_CAPTURE, 0, config));
  check(snd_pcm_set_params(pcm, SND_PCM_FORMAT_S32_LE, SND_PCM_ACCESS_RW_INTERLEAVED,
                          channels, 48000, 0, 20000));
  int32_t captured[16 * 2];
  snd_pcm_sframes_t read_frames = snd_pcm_readi(pcm, captured, 16);
  check((int)read_frames);
  assert(read_frames == 16);
  for (int i = 0; i < 16; ++i) {
    assert(captured[2 * i] == frame[0]);
    assert(captured[2 * i + 1] == frame[1]);
  }
  snd_pcm_close(pcm);
  snd_config_delete(profile);
  snd_config_delete(config);
  fclose(samples);
  puts("PASS installed UCM selects distinct channels 0/1 from four-channel S32 PCM at unity gain");
  return 0;
}
