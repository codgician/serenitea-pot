{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.herdr;
in
{
  options.codgician.codgi.herdr = {
    enable = lib.mkEnableOption "Herdr terminal workspace manager for AI coding agents";
    package = lib.mkPackageOption pkgs [ "llm-agents" "herdr" ] { };

    desktop = {
      enable = lib.mkEnableOption "Herdr desktop app and core runtime, independently of the TUI";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.llm-agents.herdr-app.override { herdr-core = cfg.desktop.corePackage; };
        defaultText = lib.literalExpression ''
          pkgs.llm-agents.herdr-app.override {
            herdr-core = config.codgician.codgi.herdr.desktop.corePackage;
          }
        '';
        description = "The Herdr desktop app package to install.";
      };

      corePackage = lib.mkPackageOption pkgs [ "llm-agents" "herdr-core" ] {
        extraDescription = "It provides the hc command.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.desktop.enable {
      home.packages = [
        cfg.desktop.package
        cfg.desktop.corePackage
      ];
    })

    # Each agent module installs its own Herdr hook and skill.
    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];

      xdg.configFile."herdr/config.toml".source = (pkgs.formats.toml { }).generate "herdr-config.toml" {
        onboarding = false;

        theme = {
          name = "catppuccin";
          auto_switch = true;
          dark_name = "catppuccin";
          light_name = "catppuccin-latte";
        };

        terminal = {
          default_shell = lib.getExe pkgs.zsh;
          shell_mode = "login";
          new_cwd = "follow";
        };

        update = {
          version_check = false;
          manifest_check = true;
        };

        ui = {
          status_indicators = "symbols";
          toast = {
            delivery = "system";
            delay_seconds = 2;
          };
          sound.enabled = false;
        };

        session.resume_agents_on_restore = true;
        experimental.pane_history = false;
      };
    })
  ];
}
