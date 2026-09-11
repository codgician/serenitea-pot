{
  lib,
  stdenv,
  fetchgit,
  fetchzip,
  gawk,
  ladspa-sdk,
  pkg-config,
  webrtc-audio-processing,
  ...
}:

let
  crasConfig = fetchzip {
    url = "https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+archive/0e50126e09cc069570ad4b19bc629254a5e5bdf5/overlay-brya/chromeos-base/chromeos-bsp-brya/files/redrix/audio/cras-config.tar.gz";
    hash = "sha256-C9B6ACbMnjf4dcg3ALej1xVaPdA3JnqISobOFUBww24=";
    stripRoot = false;
  };
  dspNames = [
    "biquad"
    "crossover2"
    "drc"
    "drc_kernel"
    "drc_math"
    "eq2"
  ];
  dspSources = lib.escapeShellArgs (map (name: "audio/hal/dsp/${name}.c") dspNames);
  dspObjects = lib.escapeShellArgs (map (name: "${name}.o") dspNames);
in
stdenv.mkDerivation {
  pname = "redrix-cras-dsp";
  version = "unstable-2026-09-08";

  src = fetchgit {
    url = "https://github.com/vartom/android_device_nvidia_dragon.git";
    rev = "2076dcef1d68a460324470de3d008c3fdbdd7d8f";
    hash = "sha256-+XGsOcgHdIaDCoQ1sglcEbYmOJE+KTI/1Nty4sNwgg8=";
  };

  nativeBuildInputs = [
    gawk
    pkg-config
  ];
  buildInputs = [ webrtc-audio-processing ];

  postPatch = ''
    cp ${./redrix-cras-dsp.c} redrix-cras-dsp.c
    cp ${./redrix-mic-apm.cpp} redrix-mic-apm.cpp
  '';

  buildPhase = ''
    runHook preBuild
    # Shared with checkPhase so sanitized and normal builds use the same inputs.
    adapterIncludes=(-I. -Iaudio/hal/dsp -I${ladspa-sdk}/include)
    webrtcCflags=( $(pkg-config --cflags webrtc-audio-processing-2)
      -isystem "$(pkg-config --variable=includedir webrtc-audio-processing-2)/webrtc-audio-processing-2" )
    webrtcLibs=( $(pkg-config --libs webrtc-audio-processing-2) )
    # Keep the ChromeOS PA curve as integer centibels.  The plugin rounds its
    # percent control before indexing this generated, complete 0..100 table.
    awk -F ' = ' '
      /^\[Speaker\][[:space:]]*$/ { speaker = 1; next }
      /^\[/ { speaker = 0 }
      speaker && $1 ~ /^[[:space:]]*db_at_[0-9]+$/ {
        position = $1
        sub(/^[[:space:]]*db_at_/, "", position)
        position += 0
        value = $2
        sub(/[[:space:]]+$/, "", value)
        if (position < 0 || position > 100 || seen[position]++ ||
            value !~ /^-?[0-9]+$/) {
          invalid = 1
        } else {
          curve[position] = value
          count++
        }
      }
      END {
        if (invalid || count != 101) exit 1
        for (position = 0; position <= 100; position++)
          if (!(position in curve)) exit 1
        print "/* Generated from the pinned ChromeOS Redrix CRAS config. */"
        print "#ifndef REDRIX_SPEAKER_CURVE_H_"
        print "#define REDRIX_SPEAKER_CURVE_H_"
        print "static const int redrix_speaker_curve_db_centibel[101] = {"
        for (position = 0; position <= 100; position++)
          printf "  %s%s", curve[position],
                 (position == 100 ? "\n" : ",\n")
        print "};"
        print "#endif"
      }
    ' ${crasConfig}/sof-rt5682.card_settings > redrix-speaker-curve.h

    # Catch incomplete descriptors and incorrect callback types in our adapter.
    $CC -std=gnu11 -O2 -Wall -Wextra -Werror -fPIC \
      "''${adapterIncludes[@]}" \
      -c redrix-cras-dsp.c -o adapter.o
    $CXX -std=c++17 -O2 -Wall -Wextra -Werror -fPIC \
      "''${webrtcCflags[@]}" -I${ladspa-sdk}/include \
      -c redrix-mic-apm.cpp -o microphone.o
    $CC -std=gnu11 -O2 -fPIC -c \
      "''${adapterIncludes[@]}" ${dspSources}
    $CXX -shared adapter.o microphone.o ${dspObjects} "''${webrtcLibs[@]}" \
      -lm -Wl,-z,defs -o redrix-cras-dsp.so
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    $CC -std=gnu11 -Wall -Wextra -Werror -I. -I${ladspa-sdk}/include \
      ${./check-plugin.c} -ldl -lm -o check-plugin
    ./check-plugin ./redrix-cras-dsp.so

    # Include the upstream DSP, not just the adapter, in memory-safety checks.
    $CC -std=gnu11 -O1 -g -fPIC -c \
      -fsanitize=address,undefined -fno-omit-frame-pointer \
      "''${adapterIncludes[@]}" redrix-cras-dsp.c ${dspSources}
    $CXX -std=c++17 -O1 -g -fPIC -c \
      -fsanitize=address,undefined -fno-omit-frame-pointer \
      "''${webrtcCflags[@]}" -I${ladspa-sdk}/include \
      redrix-mic-apm.cpp -o microphone-checked.o
    $CXX -shared -fsanitize=address,undefined redrix-cras-dsp.o microphone-checked.o \
      ${dspObjects} "''${webrtcLibs[@]}" -lm -Wl,-z,defs -o checked.so
    $CC -std=gnu11 -O1 -g -fsanitize=address,undefined \
      -I. -I${ladspa-sdk}/include ${./check-plugin.c} -ldl -lm -o check-sanitized
    ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 ./check-sanitized ./checked.so
    runHook postCheck
  '';

  installPhase = ''
    install -Dm444 redrix-cras-dsp.so $out/lib/ladspa/redrix-cras-dsp.so
    install -Dm444 redrix-speaker-curve.h $out/include/redrix-speaker-curve.h
  '';

  meta = {
    description = "Redrix speaker DSP and system microphone speech APM";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
