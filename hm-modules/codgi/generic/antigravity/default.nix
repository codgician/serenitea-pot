{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}@args:
let
  cfg = config.codgician.codgi.antigravity;
  agents = import ../agents.nix args;
  home = config.home.homeDirectory;

  # Customizations the Antigravity App, CLI and IDE all load.
  configDir = ".gemini/config";
  herdrHook = "${configDir}/hooks/herdr-agent-state.sh";

  ideUserDir =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "${home}/Library/Application Support/Antigravity IDE/User"
    else
      "${config.xdg.configHome}/Antigravity IDE/User";

  # Remote servers take `serverUrl`; a disabled server stays listed with `disabled`.
  mkMcpServer =
    name: server:
    lib.hm.mcp.transformMcpServer {
      inherit server;
      exclude = [
        "enabled"
        "url"
      ];
      extraTransforms = [ (lib.hm.mcp.wrapEnvFilesCommand { inherit pkgs name; }) ];
    }
    // lib.optionalAttrs (server.url != null) { serverUrl = server.url; }
    // lib.optionalAttrs (server.enabled == false) { disabled = true; };

  # The App, CLI and IDE all write these files, so each activation merges
  # the Nix values over what they saved instead of linking a store file.
  mutableFiles =
    lib.optionalAttrs config.codgician.codgi.mcp.enable {
      "${home}/${configDir}/mcp_config.json".mcpServers =
        lib.mapAttrs mkMcpServer config.programs.mcp.servers;
    }
    // lib.optionalAttrs cfg.cli.enable {
      "${home}/.gemini/antigravity-cli/settings.json" = {
        showFeedbackSurvey = false;
        permissions.deny = [
          "read_file(/run/secrets)"
          "command(rm -rf)"
          "command(sudo)"
        ];
      };
    }
    // lib.optionalAttrs (cfg.cli.enable && agents.herdr.enable) {
      # PreInvocation takes a flat handler list; herdr owns the `herdr` block.
      "${home}/${configDir}/hooks.json".herdr.PreInvocation = [
        {
          type = "command";
          command = "bash '${home}/${herdrHook}' session";
          timeout = 10;
        }
      ];
    }
    // lib.optionalAttrs cfg.ide.enable {
      "${ideUserDir}/settings.json" =
        let
          fontFamily = "'Cascadia Code NF', 'Cascadia Code', monospace";
        in
        {
          "editor.fontFamily" = fontFamily;
          "editor.fontSize" = 14;
          "terminal.integrated.fontFamily" = fontFamily;
          "terminal.integrated.fontSize" = 14;
          "update.mode" = "none";
        };
    };

  json5Python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.json5 ]);
  mergeJson = path: settings: ''
    ${lib.getExe json5Python} ${./merge-json.py} ${lib.escapeShellArg path} ${
      (pkgs.formats.json { }).generate "antigravity-${baseNameOf path}" settings
    }
  '';
in
{
  options.codgician.codgi.antigravity = {
    enable = lib.mkEnableOption "Antigravity customizations shared by the App, CLI and IDE";

    cli = {
      enable = lib.mkEnableOption "Antigravity CLI (agy)";
      package = lib.mkPackageOption pkgs [ "unstable" "antigravity-cli" ] { };
    };

    ide = {
      enable = lib.mkEnableOption "Antigravity IDE";
      package = lib.mkPackageOption pkgs [ "unstable" "antigravity-ide" ] { };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.llm-agents.agent-browser
    ]
    ++ lib.optional cfg.cli.enable cfg.cli.package
    ++ lib.optional cfg.ide.enable cfg.ide.package;

    home.file =
      lib.mapAttrs' (
        name: source: lib.nameValuePair "${configDir}/skills/${name}" { inherit source; }
      ) agents.skills
      // lib.optionalAttrs (cfg.cli.enable && agents.herdr.enable) {
        ${herdrHook} = agents.herdr.hookFile "antigravity_cli";
      };

    home.activation.antigravityMutableSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      lib.concatStrings (lib.mapAttrsToList mergeJson mutableFiles)
    );
  };
}
