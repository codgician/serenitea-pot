{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.herdr;
  tomlFormat = pkgs.formats.toml { };
  jsonFormat = pkgs.formats.json { };

  integrationsDir = "${cfg.package}/share/herdr/integrations";
  homeDir = config.home.homeDirectory;
  enabled = name: config.codgician.codgi.${name}.enable or false;
  absolutePath = path: if lib.hasPrefix "/" path then path else "${homeDir}/${path}";

  claudeConfigDir = absolutePath config.programs.claude-code.configDir;
  claudeHook = "${claudeConfigDir}/hooks/herdr-agent-state.sh";

  codexConfigDir =
    if config.home.preferXdgDirectories then "${config.xdg.configHome}/codex" else "${homeDir}/.codex";
  codexHook = "${codexConfigDir}/herdr-agent-state.sh";

  copilotConfigDir = absolutePath config.programs.github-copilot-cli.configDir;
  copilotHook = "${copilotConfigDir}/hooks/herdr-agent-state.sh";
  ompProfiles = import ../oh-my-pi/profiles { inherit pkgs; };

  ompIntegrationFiles = lib.mapAttrs' (
    name: _:
    lib.nameValuePair ".omp/profiles/${name}/agent/extensions/herdr-omp-agent-state.ts" {
      source = "${integrationsDir}/omp/herdr-agent-state.ts";
    }
  ) ompProfiles;
in
{
  options.codgician.codgi.herdr = {
    enable = lib.mkEnableOption "Herdr terminal workspace manager for AI coding agents";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.herdr;
      defaultText = lib.literalExpression "pkgs.herdr";
      description = "The Herdr package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile = {
      "herdr/config.toml".source = tomlFormat.generate "herdr-config.toml" {
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
    }
    // lib.optionalAttrs (enabled "opencode") {
      # Herdr checks tui.jsonc when reporting integration status. Keep this
      # declarative copy aligned with Home Manager's generated tui.json.
      "opencode/tui.jsonc".source = jsonFormat.generate "opencode-herdr-tui.jsonc" (
        {
          "$schema" = "https://opencode.ai/tui.json";
        }
        // config.programs.opencode.tui
      );
    };

    home.file = lib.mkMerge [
      (lib.optionalAttrs (enabled "pi-coding-agent") {
        ".pi/agent/extensions/herdr-agent-state.ts".source = "${integrationsDir}/pi/herdr-agent-state.ts";
      })

      (lib.optionalAttrs (enabled "oh-my-pi") (
        {
          ".omp/agent/extensions/herdr-omp-agent-state.ts".source =
            "${integrationsDir}/omp/herdr-agent-state.ts";
        }
        // ompIntegrationFiles
      ))

      (lib.optionalAttrs (enabled "claude-code") {
        "${config.programs.claude-code.configDir}/hooks/herdr-agent-state.sh" = {
          source = "${integrationsDir}/claude/herdr-agent-state.sh";
          executable = true;
        };
      })

      (lib.optionalAttrs (enabled "codex") {
        "${lib.removePrefix "${homeDir}/" codexConfigDir}/herdr-agent-state.sh" = {
          source = "${integrationsDir}/codex/herdr-agent-state.sh";
          executable = true;
        };
        "${lib.removePrefix "${homeDir}/" codexConfigDir}/hooks.json".source =
          jsonFormat.generate "codex-herdr-hooks.json"
            {
              hooks.SessionStart = [
                {
                  hooks = [
                    {
                      type = "command";
                      command = "bash '${codexHook}' session";
                      timeout = 10;
                    }
                  ];
                }
              ];
            };
      })

      (lib.optionalAttrs (enabled "github-copilot-cli") {
        "${config.programs.github-copilot-cli.configDir}/hooks/herdr-agent-state.sh" = {
          source = "${integrationsDir}/copilot/herdr-agent-state.sh";
          executable = true;
        };
        "${config.programs.github-copilot-cli.configDir}/settings.json".source =
          jsonFormat.generate "copilot-herdr-settings.json"
            {
              hooks.SessionStart = [
                {
                  type = "command";
                  bash = "bash '${copilotHook}'";
                  timeoutSec = 10;
                }
              ];
            };
      })

      (lib.optionalAttrs (enabled "droid") {
        ".factory/hooks/herdr-agent-state.sh" = {
          source = "${integrationsDir}/droid/herdr-agent-state.sh";
          executable = true;
        };
      })

      (lib.optionalAttrs (enabled "opencode") {
        ".config/opencode/plugins/herdr-agent-state.js".source =
          "${integrationsDir}/opencode/herdr-agent-state.js";
        ".config/opencode/herdr-tui-session.js".source = "${integrationsDir}/opencode/herdr-tui-session.js";
      })
    ];

    programs.claude-code.settings = lib.mkIf (enabled "claude-code") {
      hooks.SessionStart = [
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = "bash '${claudeHook}' session";
              timeout = 10;
            }
          ];
        }
      ];
    };

    programs.codex.settings.features.hooks = lib.mkIf (enabled "codex") true;

  };
}
