{
  speakerNode ? "alsa_output.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Speaker__sink",
  micNode ? "alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source",
}:
let
  graphs = import ./filter-chain.nix;
  speakerBackend = "${speakerNode}.raw";
  micBackend = "${micNode}.raw";
  privateStream = {
    "node.passive" = true;
    "node.linger" = true;
    "node.dont-fallback" = true;
    "node.dont-move" = true;
    "state.restore-props" = false;
    "state.restore-target" = false;
    "channelmix.lock-volumes" = true;
  };
  publicEndpoint = {
    "node.virtual" = true;
    # ALSA Route state and virtual stream state are different namespaces. Start
    # safely silent on the first cutover; WirePlumber remembers later choices.
    "state.default-volume" = 0.0;
  };
  audio = {
    "audio.rate" = 48000;
    "audio.channels" = 2;
    "audio.position" = [
      "FL"
      "FR"
    ];
  };
in
{
  inherit
    speakerNode
    micNode
    speakerBackend
    micBackend
    ;
  rules = [
    {
      matches = [ { "node.name" = speakerBackend; } ];
      actions.create-filter = {
        hide-parent = true;
        filter-graph = builtins.toJSON (
          audio
          // {
            "node.description" = "Redrix speaker DSP";
            "filter.graph" = graphs.speaker;
            "capture.props" = publicEndpoint // {
              "node.name" = speakerNode;
              "node.description" = "Speakers";
              "media.class" = "Audio/Sink";
              "application.id" = "org.codgician.redrix.speaker";
              "priority.session" = 1000;
            };
            "playback.props" = privateStream // {
              "node.name" = "redrix.speaker.playback";
              "target.object" = speakerBackend;
            };
          }
        );
      };
    }
    {
      matches = [ { "node.name" = micBackend; } ];
      actions.create-filter = {
        hide-parent = true;
        filter-graph = builtins.toJSON (
          audio
          // {
            "node.description" = "Redrix microphone APM";
            "filter.graph" = graphs.microphone;
            "capture.props" = privateStream // {
              "node.name" = "redrix.microphone.capture";
              "target.object" = micBackend;
            };
            "playback.props" = publicEndpoint // {
              "node.name" = micNode;
              "node.description" = "Internal Microphone";
              "media.class" = "Audio/Source";
              "application.id" = "org.codgician.redrix.microphone";
              "priority.session" = 1600;
            };
          }
        );
      };
    }
  ];
}
