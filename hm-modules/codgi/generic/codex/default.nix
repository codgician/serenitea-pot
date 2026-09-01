{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.codex;
  codexConfigDir =
    if config.home.preferXdgDirectories then
      "${lib.removePrefix config.home.homeDirectory config.xdg.configHome}/codex"
    else
      ".codex";

  codexConfigFile =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex/config.toml"
    else
      "${config.home.homeDirectory}/.codex/config.toml";
  tomlkitPython = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.tomlkit ]);
  staticSettings =
    (pkgs.formats.toml { }).generate "codex-static-settings"
      config.programs.codex.settings;

in
{
  options.codgician.codgi.codex = {
    enable = lib.mkEnableOption "Codex";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llm-agents.codex;
      defaultText = lib.literalExpression "pkgs.llm-agents.codex";
      description = ''
        The Codex package to install.
      '';
    };

  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.nur.repos.codgician.agent-browser ];

    # Link skills directory to ~/.agents/skills
    home.file.".agents/skills".source = pkgs.symlinkJoin {
      name = "codex-skills";
      paths = [
        "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
      ]
      ++ lib.optionals (config.codgician.codgi.herdr.enable or false) [
        "${config.codgician.codgi.herdr.package.src}/skills"
      ];
    };

    programs.codex = {
      enable = true;
      package = cfg.package;
      enableMcpIntegration = config.codgician.codgi.mcp.enable;
      settings = {
        model_provider = "litellm";
        model_providers.litellm = {
          name = "LiteLLM";
          base_url = "https://dendro.codgician.me/v1";
          env_key = "OPENAI_API_KEY";
          wire_api = "responses";
        };
        model = "gpt-5.6-sol";
      };
    };

    # TODO: Replace this workaround with Home Manager's native mutable-settings
    # option when https://github.com/nix-community/home-manager/issues/9397 merges.

    home.file."${codexConfigDir}/config.toml".enable = false;

    home.activation.codexMutableSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${lib.getExe tomlkitPython} ${./merge-settings.py} ${lib.escapeShellArg codexConfigFile} ${lib.escapeShellArg staticSettings}
    '';

  };
}
