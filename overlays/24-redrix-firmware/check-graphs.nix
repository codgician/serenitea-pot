{
  runCommand,
  stdenv,
  alsa-lib,
  python3,
  writeText,
  redrix,
  pipewire ? redrix.pipewire,
}:
let
  graphs = writeText "redrix-graphs.json" (builtins.toJSON (import ./filter-chain.nix));
in
runCommand "redrix-pipewire-graph-check"
  {
    nativeBuildInputs = [ stdenv.cc ];
    buildInputs = [ alsa-lib ];
  }
  ''
    $CC -std=gnu11 -Wall -Wextra -Werror ${./check-microphone-route.c} -lasound -o check-microphone-route
    ./check-microphone-route ${redrix.chromeos-ucm}/share/alsa/ucm2/conf.d/sof-rt5682/HiFi.conf
    ${python3}/bin/python3 ${./check-pipewire-graphs.py} \
      ${pipewire} ${redrix.cras-dsp}/lib/ladspa ${graphs}
    touch "$out"
  ''
