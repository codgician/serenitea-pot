{ config, pkgs, ... }:
let
  dsp = import ../../../overlays/24-redrix-firmware/software-dsp.nix { };
in
{
  # Exercise the same host and native WirePlumber policy without real hardware.
  system.checks = [
    (pkgs.redrix.check-graphs.override {
      pipewire = config.services.pipewire.package;
      wireplumber = config.services.pipewire.wireplumber.package;
    })
  ];

  services.pipewire.wireplumber = {
    extraLadspaPackages = [ pkgs.redrix.cras-dsp ];
    extraConfig."51-redrix-audio" = {
      "wireplumber.profiles".main = {
        "pw.node-factory.adapter" = "required";
        "node.software-dsp" = "required";
      };
      "node.software-dsp.rules" = dsp.rules;
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = dsp.speakerNode; } ];
          actions.update-props = {
            "node.name" = dsp.speakerBackend;
            "node.description" = "Redrix speaker backend";
            "node.nick" = "Redrix speaker backend";
            "audio.format" = "S16LE";
            "audio.rate" = 48000;
            # Only the processed public endpoint owns desktop volume/mute.
            "channelmix.lock-volumes" = true;
            "priority.session" = 1;
          };
        }
        {
          matches = [ { "node.name" = dsp.micNode; } ];
          actions.update-props = {
            "node.name" = dsp.micBackend;
            "node.description" = "Redrix microphone backend";
            "node.nick" = "Redrix microphone backend";
            "audio.format" = "S32LE";
            "audio.rate" = 48000;
            "channelmix.lock-volumes" = true;
            "priority.session" = 1;
          };
        }
      ];
    };
  };
  # Upstream node.software-dsp owns filter lifetime and parent visibility.
  # Existing WirePlumber state stores endpoint volumes; no new service or state directory.
}
