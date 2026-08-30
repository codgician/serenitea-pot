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
    # Bypass programs.github-copilot-cli.skills: Home Manager inspects those paths
    # during evaluation, which would realize this target-platform source derivation.
    home.file."${config.programs.github-copilot-cli.configDir}/skills/agent-browser".source =
      "${pkgs.nur.repos.codgician.agent-browser.src}/skills/agent-browser";
    programs.github-copilot-cli = {
      enable = true;
      inherit (cfg) package;
      enableMcpIntegration = config.codgician.codgi.mcp.enable;
    };
  };
}
