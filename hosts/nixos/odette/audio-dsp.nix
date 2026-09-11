{ config, pkgs, ... }:
let
  speakerNode = "alsa_output.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Speaker__sink";
  micNode = "alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source";
  graphs = import ../../../overlays/24-redrix-firmware/filter-chain.nix;
in
{
  # Exercise the same patched host with file/null PCMs, never real hardware.
  system.checks = [
    (pkgs.redrix.check-graphs.override { pipewire = config.services.pipewire.package; })
  ];

  # Embedded graphs only load plugins from their host's allowed LADSPA path.
  services.pipewire.extraLadspaPackages = [ pkgs.redrix.cras-dsp ];
  services.pipewire.wireplumber = {
    extraLadspaPackages = [ pkgs.redrix.cras-dsp ];
    extraConfig."51-redrix-audio" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = speakerNode; } ];
          actions.update-props = {
            "node.description" = "Speakers";
            "node.nick" = "Speakers";
            "audio.format" = "S16LE";
            "audio.rate" = 48000;
            "audioconvert.filter-graph.0" = builtins.toJSON graphs.speaker;
            # The graph consumes channelVolumes/mute itself. Keep the adapter
            # at unity, including during the plugin's sample-domain mute ramp.
            "channelmix.lock-volumes" = true;
            "audioconvert.filter-graph.disable" = true;
          };
        }
        {
          matches = [ { "node.name" = micNode; } ];
          actions.update-props = {
            "node.description" = "Internal Microphone";
            "node.nick" = "Internal Microphone";
            "audio.format" = "S32LE";
            "audio.rate" = 48000;
            "audioconvert.filter-graph.0" = builtins.toJSON graphs.microphone;
            "channelmix.lock-volumes" = true;
            "audioconvert.filter-graph.disable" = true;
          };
        }
      ];
    };
  };
  # Device graphs follow ALSA node creation/destruction. No custom runtime
  # script, service, persistent state or tmpfiles directory is needed.
}
