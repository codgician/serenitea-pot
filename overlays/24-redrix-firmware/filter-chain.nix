# Standalone speaker correction graph, loaded by the systemd user service.
{ plugin, target }:
{
  "context.properties" = {
    "log.level" = 2;
    "cpu.zero.denormals" = true;
  };
  "context.spa-libs" = {
    "audio.convert.*" = "audioconvert/libspa-audioconvert";
    "support.*" = "support/libspa-support";
  };
  "context.modules" = [
    { name = "libpipewire-module-protocol-native"; }
    { name = "libpipewire-module-client-node"; }
    { name = "libpipewire-module-adapter"; }
    {
      name = "libpipewire-module-filter-chain";
      args = {
        "node.description" = "Redrix CRAS DSP (experimental)";
        "audio.rate" = 48000;
        "audio.channels" = 2;
        "audio.position" = [
          "FL"
          "FR"
        ];
        "filter.graph" = {
          nodes = [
            {
              type = "ladspa";
              name = "cras";
              # Absolute path: independent of the desktop's LADSPA_PATH.
              plugin = "${plugin}/lib/ladspa/redrix-cras-dsp.so";
              label = "redrix_cras_dsp";
            }
          ];
          inputs = [
            "cras:Input Left"
            "cras:Input Right"
          ];
          outputs = [
            "cras:Output Left"
            "cras:Output Right"
          ];
        };
        "capture.props" = {
          "node.name" = "redrix_chromeos_sink";
          "node.description" = "Redrix internal speaker correction";
          "media.class" = "Audio/Sink";
          "node.virtual" = true;
          "priority.session" = 0;
          "filter.smart" = true;
          "filter.smart.name" = "redrix-speakers";
          "filter.smart.target" = {
            "node.name" = target;
          };
          "filter.smart.targetable" = false;
          "stream.dont-remix" = true;
        };
        "playback.props" = {
          "node.name" = "redrix_chromeos_output";
          "target.object" = target;
          "node.passive" = true;
          "node.dont-fallback" = true;
          "node.dont-move" = true;
          "node.linger" = true;
        };
      };
    }
  ];
}
