{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.easyeffects;
  jsonFormat = pkgs.formats.json { };
  directions = [
    "input"
    "output"
  ];

  presetType = lib.types.submodule {
    options = {
      direction = lib.mkOption {
        type = lib.types.enum directions;
        default = "output";
        description = "Whether this preset applies to the input or output pipeline.";
      };

      content = lib.mkOption {
        type = lib.types.either lib.types.path (lib.types.attrsOf jsonFormat.type);
        description = ''
          Preset content: either inline settings (an attrset, as they'd
          appear under the `"input"`/`"output"` key of an exported preset
          file) or a `path` to a complete preset JSON file.
        '';
      };
    };
  };

  autoloadType = lib.types.submodule {
    options = {
      direction = lib.mkOption {
        type = lib.types.enum directions;
        default = "output";
        description = "Whether this rule applies to the input or output pipeline.";
      };

      device = lib.mkOption {
        type = lib.types.str;
        description = "PipeWire node name, e.g. `alsa_output.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Speaker__sink`.";
      };

      deviceDescription = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Human-readable device description shown in the EasyEffects UI.";
      };

      deviceProfile = lib.mkOption {
        type = lib.types.str;
        description = ''Device profile string, e.g. "HiFi: Speaker: sink".'';
      };

      preset = lib.mkOption {
        type = lib.types.str;
        description = "Name of a preset declared in `presets` to autoload for this device and profile.";
      };
    };
  };

  presetFiles = lib.mapAttrs' (
    name: preset:
    lib.nameValuePair "easyeffects/${preset.direction}/${name}.json" (
      if builtins.typeOf preset.content == "path" then
        { source = preset.content; }
      else
        { text = builtins.toJSON { ${preset.direction} = preset.content; }; }
    )
  ) cfg.presets;

  autoloadFiles = lib.listToAttrs (
    map (
      rule:
      lib.nameValuePair "easyeffects/autoload/${rule.direction}/${rule.device}:${rule.deviceProfile}.json"
        {
          text = builtins.toJSON {
            device = rule.device;
            device-description = rule.deviceDescription;
            device-profile = rule.deviceProfile;
            preset-name = rule.preset;
          };
        }
    ) cfg.autoload
  );

  fallbackWindowSettings = lib.mergeAttrsList (
    map (
      direction:
      lib.optionalAttrs (cfg.fallback.${direction} != null) {
        "${direction}AutoloadingFallbackPreset" = cfg.fallback.${direction};
        "${direction}AutoloadingUsesFallback" = true;
      }
    ) directions
  );

  unknownAutoloadPresets = lib.unique (
    builtins.filter (preset: !builtins.hasAttr preset cfg.presets) (map (r: r.preset) cfg.autoload)
  );
  unknownFallbackPresets = builtins.filter (
    preset: preset != null && !builtins.hasAttr preset cfg.presets
  ) (builtins.attrValues cfg.fallback);
in
{
  options.codgician.codgi.easyeffects = {
    enable = lib.mkEnableOption "EasyEffects audio effects daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.easyeffects;
      defaultText = lib.literalExpression "pkgs.easyeffects";
      description = "The EasyEffects package to install.";
    };

    presets = lib.mkOption {
      type = lib.types.attrsOf presetType;
      default = { };
      description = ''
        Presets to install under `$XDG_DATA_HOME/easyeffects/{input,output}`.
        Reference these by name from `autoload` or `fallback`.
      '';
    };

    autoload = lib.mkOption {
      type = lib.types.listOf autoloadType;
      default = [ ];
      description = "Per-device preset autoload rules.";
    };

    fallback = lib.genAttrs directions (
      direction:
      lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Preset name to fall back to for ${direction} devices with no autoload rule.";
      }
    );
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = unknownAutoloadPresets == [ ];
        message = "codgician.codgi.easyeffects.autoload references undeclared presets: ${toString unknownAutoloadPresets}.";
      }
      {
        assertion = unknownFallbackPresets == [ ];
        message = "codgician.codgi.easyeffects.fallback references undeclared presets: ${toString unknownFallbackPresets}.";
      }
    ];

    # Run EasyEffects as a systemd user service tied to graphical-session.target
    # rather than relying on its own GUI-driven "Autostart on login" toggle: that
    # toggle only writes ~/.config/autostart/com.github.wwmm.easyeffects.desktop
    # the first time it's flipped in the running app (non-reproducible from Nix),
    # and even then systemd-xdg-autostart-generator can silently skip the entry
    # when Exec="easyeffects" isn't resolvable in its generator-time PATH
    # (see https://github.com/wwmm/easyeffects/issues/4738). A declarative
    # systemd user unit with an absolute ExecStart sidesteps both failure modes.
    services.easyeffects = {
      enable = true;
      inherit (cfg) package;
    };

    xdg.dataFile = presetFiles // autoloadFiles;

    programs.plasma.configFile."easyeffects/db/easyeffectsrc".Window = fallbackWindowSettings;
  };
}
