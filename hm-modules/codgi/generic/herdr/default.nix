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
    desktop.enable = lib.mkEnableOption "Herdr desktop app and core runtime, independently of the TUI";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.desktop.enable {
      home.packages = [
        pkgs.llm-agents.herdr-app
        pkgs.llm-agents.herdr-core
      ];
    })

    # Each agent module installs its own Herdr hook and skill.
    (lib.mkIf cfg.enable {
      home.packages = [ pkgs.llm-agents.herdr ];

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
