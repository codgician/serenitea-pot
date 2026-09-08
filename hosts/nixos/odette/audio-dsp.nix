{ pkgs, ... }:
let
  speakerNode = "alsa_output.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Speaker__sink";
  filterConfig = pkgs.writeText "redrix-speaker-dsp.conf" (
    builtins.toJSON (
      import ../../../overlays/24-redrix-firmware/filter-chain.nix {
        plugin = pkgs.redrix.cras-dsp;
        target = speakerNode;
      }
    )
  );
in
{
  services.pipewire = {
    wireplumber = {
      extraScripts."redrix/hide-filter.lua" =
        builtins.readFile ../../../overlays/24-redrix-firmware/hide-filter.lua;
      extraScripts."redrix/monitor-target.lua" =
        builtins.readFile ../../../overlays/24-redrix-firmware/monitor-target.lua;
      extraConfig."51-redrix-speaker-name"."monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = speakerNode; } ];
          actions.update-props = {
            "node.description" = "Speakers";
            "node.nick" = "Speakers";
          };
        }
      ];
      extraConfig."51-redrix-filter-visibility" = {
        "wireplumber.components" = [
          {
            name = "redrix/hide-filter.lua";
            type = "script/lua";
            provides = "custom.redrix-filter-visibility";
          }
          {
            name = "redrix/monitor-target.lua";
            type = "script/lua";
            provides = "custom.redrix-monitor-target";
          }
        ];
        "wireplumber.profiles".main."custom.redrix-filter-visibility" = "required";
        "wireplumber.profiles".main."custom.redrix-monitor-target" = "required";
      };
    };
  };

  # Processing is transparent to applications and isolated from the audio server.
  # No persistent state or writable directories are needed by this service.
  systemd.user.services.redrix-speaker-dsp = {
    description = "Redrix speaker correction (isolated process)";
    wantedBy = [ "pipewire.service" ];
    partOf = [
      "pipewire.service"
      "wireplumber.service"
    ];
    wants = [ "wireplumber.service" ];
    after = [
      "pipewire.service"
      "wireplumber.service"
    ];
    bindsTo = [ "pipewire.service" ];
    conflicts = [ "easyeffects.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.pipewire}/bin/pipewire -c ${filterConfig}";
      Restart = "on-failure";
      RestartSec = 2;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      LimitCORE = 0;
    };
  };
}
