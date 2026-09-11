{
  runCommand,
  stdenv,
  alsa-lib,
  python3,
  writeText,
  redrix,
  pipewire,
  wireplumber,
  dbus,
}:
let
  policy = writeText "redrix-software-dsp.json" (
    builtins.toJSON (
      import ./software-dsp.nix {
        speakerNode = "test.speaker";
        micNode = "test.microphone";
      }
    )
  );
in
runCommand "redrix-pipewire-graph-check"
  {
    nativeBuildInputs = [
      stdenv.cc
      dbus
    ];
    buildInputs = [ alsa-lib ];
  }
  ''
    $CC -std=gnu11 -Wall -Wextra -Werror ${./check-microphone-route.c} -lasound -o check-microphone-route
    ./check-microphone-route ${redrix.chromeos-ucm}/share/alsa/ucm2/conf.d/sof-rt5682/HiFi.conf
    ${dbus}/bin/dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf \
      -- ${python3}/bin/python3 ${./check-pipewire-graphs.py} \
      ${pipewire} ${wireplumber} ${redrix.cras-dsp}/lib/ladspa ${policy}
    touch "$out"
  ''
