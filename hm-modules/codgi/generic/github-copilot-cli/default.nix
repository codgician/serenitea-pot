{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.github-copilot-cli;

in
{
  options.codgician.codgi.github-copilot-cli = {
    enable = lib.mkEnableOption "GitHub Copilot CLI";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llm-agents.copilot-cli;
      defaultText = lib.literalExpression "pkgs.llm-agents.copilot-cli";
      description = ''
        The GitHub Copilot CLI package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.nur.repos.codgician.agent-browser ];
    # Own the directory symlink so Home Manager can replace stale generations.
    home.file."${config.programs.github-copilot-cli.configDir}/skills".source = pkgs.symlinkJoin {
      name = "copilot-cli-skills";
      paths = [
        "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
      ]
      ++ lib.optionals (config.codgician.codgi.herdr.enable or false) [
        "${config.codgician.codgi.herdr.package.src}/skills"
      ];
    };
    programs.github-copilot-cli = {
      enable = true;
      inherit (cfg) package;
      enableMcpIntegration = config.codgician.codgi.mcp.enable;
    };
  };
}
