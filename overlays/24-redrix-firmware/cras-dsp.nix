{
  lib,
  stdenv,
  fetchgit,
  ladspa-sdk,
  ...
}:

stdenv.mkDerivation {
  pname = "redrix-cras-dsp";
  version = "unstable-2026-09-08";

  src = fetchgit {
    url = "https://github.com/vartom/android_device_nvidia_dragon.git";
    rev = "2076dcef1d68a460324470de3d008c3fdbdd7d8f";
    hash = "sha256-+XGsOcgHdIaDCoQ1sglcEbYmOJE+KTI/1Nty4sNwgg8=";
  };

  postPatch = ''
    cp ${./redrix-cras-dsp.c} redrix-cras-dsp.c
  '';

  buildPhase = ''
    runHook preBuild
    # Catch incomplete descriptors and incorrect callback types in our adapter.
    $CC -std=gnu11 -O2 -Wall -Wextra -Werror -fPIC \
      -Iaudio/hal/dsp -I${ladspa-sdk}/include \
      -c redrix-cras-dsp.c -o adapter.o
    $CC -std=gnu11 -O2 -fPIC -shared \
      -Iaudio/hal/dsp -I${ladspa-sdk}/include \
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
    $CC -std=gnu11 -Wall -Wextra -Werror -I${ladspa-sdk}/include \
      ${./check-plugin.c} -ldl -lm -o check-plugin
    ./check-plugin ./redrix-cras-dsp.so

    # Include the upstream DSP, not just the adapter, in memory-safety checks.
    $CC -std=gnu11 -O1 -g -fPIC -shared \
      -fsanitize=address,undefined -fno-omit-frame-pointer \
      -Iaudio/hal/dsp -I${ladspa-sdk}/include \
      redrix-cras-dsp.c audio/hal/dsp/{biquad,crossover2,drc,drc_kernel,drc_math,eq2}.c \
      -lm -Wl,-z,defs -o checked.so
    $CC -std=gnu11 -O1 -g -fsanitize=address,undefined \
      -I${ladspa-sdk}/include ${./check-plugin.c} -ldl -lm -o check-sanitized
    ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 ./check-sanitized ./checked.so
    runHook postCheck
  '';

  installPhase = ''
    install -Dm444 redrix-cras-dsp.so $out/lib/ladspa/redrix-cras-dsp.so
  '';

  meta = {
    description = "Redrix ChromeOS CRAS speaker DSP as a LADSPA plugin";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
