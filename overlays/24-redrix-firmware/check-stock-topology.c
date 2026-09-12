/* Validate the stock binary topology against the Redrix routes used by UCM. */
#include <endian.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sound/asoc.h>

static void require(bool condition, const char *message) {
  if (!condition) {
    fprintf(stderr, "Redrix topology: %s\n", message);
    exit(1);
  }
}

static void read_exact(FILE *file, void *data, size_t size) {
  require(fread(data, 1, size, file) == size, "truncated topology");
}

static void skip_private(FILE *file, uint32_t size) {
  require(fseek(file, le32toh(size), SEEK_CUR) == 0, "cannot skip private data");
}

static void check_caps(const struct snd_soc_tplg_stream_caps *caps,
                       unsigned int channels, unsigned int format) {
  require(le32toh(caps->rate_min) <= 48000 && le32toh(caps->rate_max) >= 48000,
          "required PCM does not support 48 kHz");
  require(le32toh(caps->channels_min) <= channels && le32toh(caps->channels_max) >= channels,
          "required PCM channel count is unsupported");
  require((le64toh(caps->formats) & (UINT64_C(1) << format)) != 0,
          "required PCM sample format is unsupported");
}

int main(int argc, char **argv) {
  require(argc == 2, "expected a topology file");
  FILE *file = fopen(argv[1], "rb");
  require(file != NULL, "cannot open topology");
  unsigned int speakers = 0, microphones = 0, speaker_links = 0;
  struct snd_soc_tplg_hdr header;
  while (fread(&header, 1, sizeof(header), file) != 0) {
    require(!feof(file) && !ferror(file), "truncated block header");
    require(le32toh(header.magic) == SND_SOC_TPLG_MAGIC &&
            le32toh(header.abi) == SND_SOC_TPLG_ABI_VERSION &&
            le32toh(header.size) == sizeof(header), "unsupported topology header");
    long start = ftell(file);
    require(start >= 0, "cannot determine block position");
    for (uint32_t i = 0; i < le32toh(header.count); ++i) {
      if (le32toh(header.type) == SND_SOC_TPLG_TYPE_PCM) {
        struct snd_soc_tplg_pcm pcm;
        read_exact(file, &pcm, sizeof(pcm));
        require(le32toh(pcm.size) == sizeof(pcm), "unsupported PCM layout");
        if (le32toh(pcm.pcm_id) == 0) {
          require(le32toh(pcm.playback), "PCM0 is not playback");
          check_caps(&pcm.caps[0], 2, SNDRV_PCM_FORMAT_S16_LE);
          ++speakers;
        } else if (le32toh(pcm.pcm_id) == 99) {
          require(le32toh(pcm.capture), "PCM99 is not capture");
          check_caps(&pcm.caps[1], 4, SNDRV_PCM_FORMAT_S32_LE);
          ++microphones;
        }
        skip_private(file, pcm.priv.size);
      } else if (le32toh(header.type) == SND_SOC_TPLG_TYPE_BACKEND_LINK) {
        struct snd_soc_tplg_link_config link;
        read_exact(file, &link, sizeof(link));
        require(le32toh(link.size) == sizeof(link), "unsupported link layout");
        if (strncmp(link.name, "SSP1-Codec", sizeof(link.name)) == 0) {
          uint32_t count = le32toh(link.num_hw_configs);
          require(count <= SND_SOC_TPLG_HW_CONFIG_MAX, "invalid hardware config count");
          for (uint32_t j = 0; j < count; ++j) {
            const struct snd_soc_tplg_hw_config *hw = &link.hw_config[j];
            if (le32toh(hw->id) != le32toh(link.default_hw_config_id)) continue;
            require(le32toh(hw->fmt) == SND_SOC_DAI_FORMAT_DSP_B &&
                    le32toh(hw->mclk_rate) == 19200000 &&
                    le32toh(hw->bclk_rate) == 6144000 &&
                    le32toh(hw->fsync_rate) == 48000 &&
                    le32toh(hw->tdm_slots) == 4 && le32toh(hw->tdm_slot_width) == 32 &&
                    le32toh(hw->tx_slots) == 3 && le32toh(hw->rx_slots) == 15,
                    "speaker SSP clock or four-amplifier slot mapping changed");
            ++speaker_links;
          }
        }
        skip_private(file, link.priv.size);
      } else {
        require(fseek(file, le32toh(header.payload_size), SEEK_CUR) == 0,
                "cannot skip topology block");
        break;
      }
    }
    require(ftell(file) - start == le32toh(header.payload_size), "invalid block length");
  }
  require(!ferror(file), "topology read failed");
  fclose(file);
  require(speakers == 1 && microphones == 1 && speaker_links == 1,
          "required speaker, microphone or amplifier route is missing or duplicated");
  puts("PASS stock topology supports PCM0 stereo, PCM99 four-channel S32 and Redrix amplifier clocks/slots");
  return 0;
}
