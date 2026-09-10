{
  lib,
  stdenv,
  fetchgit,
  fetchzip,
  gawk,
  ladspa-sdk,
  ...
}:

let
  crasConfig = fetchzip {
    url = "https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+archive/0e50126e09cc069570ad4b19bc629254a5e5bdf5/overlay-brya/chromeos-base/chromeos-bsp-brya/files/redrix/audio/cras-config.tar.gz";
    hash = "sha256-C9B6ACbMnjf4dcg3ALej1xVaPdA3JnqISobOFUBww24=";
    stripRoot = false;
  };
in
stdenv.mkDerivation {
  pname = "redrix-cras-dsp";
  version = "unstable-2026-09-08";

  src = fetchgit {
    url = "https://github.com/vartom/android_device_nvidia_dragon.git";
    rev = "2076dcef1d68a460324470de3d008c3fdbdd7d8f";
    hash = "sha256-+XGsOcgHdIaDCoQ1sglcEbYmOJE+KTI/1Nty4sNwgg8=";
  };

  nativeBuildInputs = [ gawk ];

  postPatch = ''
    cp ${./redrix-cras-dsp.c} redrix-cras-dsp.c
  '';

  buildPhase = ''
    runHook preBuild
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
      -I. -Iaudio/hal/dsp -I${ladspa-sdk}/include \
      -c redrix-cras-dsp.c -o adapter.o
    $CC -std=gnu11 -O2 -fPIC -shared \
      -I. -Iaudio/hal/dsp -I${ladspa-sdk}/include \
      adapter.o \
      audio/hal/dsp/biquad.c \
      audio/hal/dsp/crossover2.c \
      audio/hal/dsp/drc.c \
      audio/hal/dsp/drc_kernel.c \
      audio/hal/dsp/drc_math.c \
      audio/hal/dsp/eq2.c \
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
    $CC -std=gnu11 -O1 -g -fPIC -shared \
      -fsanitize=address,undefined -fno-omit-frame-pointer \
      -I. -Iaudio/hal/dsp -I${ladspa-sdk}/include \
      redrix-cras-dsp.c audio/hal/dsp/{biquad,crossover2,drc,drc_kernel,drc_math,eq2}.c \
      -lm -Wl,-z,defs -o checked.so
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
    description = "Redrix ChromeOS CRAS DSP and gain LADSPA descriptors";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
