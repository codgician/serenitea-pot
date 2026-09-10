{ pkgs, ... }:
let
  speakerNode = "alsa_output.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Speaker__sink";
  micNode = "alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source";
  graphs = import ../../../overlays/24-redrix-firmware/filter-chain.nix;
in
{
  # Embedded graphs only load plugins from their host's allowed LADSPA path.
  services.pipewire.extraLadspaPackages = [ pkgs.redrix.cras-dsp ];
  services.pipewire.wireplumber = {
    extraLadspaPackages = [ pkgs.redrix.cras-dsp ];
    extraScripts."redrix/noise-reduction.lua" =
      builtins.readFile ../../../overlays/24-redrix-firmware/noise-reduction.lua;
    extraConfig."51-redrix-audio" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = speakerNode; } ];
          actions.update-props = {
            "node.description" = "Speakers";
            "node.nick" = "Speakers";
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
            "audioconvert.filter-graph.0" = builtins.toJSON graphs.microphone;
            "channelmix.lock-volumes" = true;
            "audioconvert.filter-graph.disable" = true;
            "api.alsa.bind-ctls" = [ "RTNR10.0 rtnr_enable_10" ];
          };
        }
      ];
      "wireplumber.settings.schema"."redrix.noise-reduction" = {
        name = "Internal microphone noise reduction";
        description = "Enable the Redrix firmware RTNR effect, independently of application processing";
        type = "bool";
        default = true;
      };
      "wireplumber.components" = [
        {
          name = "redrix/noise-reduction.lua";
          type = "script/lua";
          provides = "custom.redrix-noise-reduction";
          # WP 0.5's dependency parser keeps JSON string quotes as part of IDs.
          requires = "[ support.settings monitor.alsa ]";
          arguments."node.name" = micNode;
          arguments."alsa.card" = "sofrt5682";
        }
      ];
      "wireplumber.profiles".main."custom.redrix-noise-reduction" = "required";
    };
  };
  # No new service or writable directory: device graphs follow ALSA node
  # creation/destruction. The existing persisted /home covers WP settings.
}
