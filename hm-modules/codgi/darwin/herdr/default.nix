{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.herdr;
  agents = import ../../generic/agents.nix { inherit config osConfig pkgs; };
  agentPackages = [ pkgs.llm-agents.herdr ] ++ agents.enabledPackages;
in
{
  config = lib.mkIf cfg.enable {
    launchd.agents.herdr = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe pkgs.llm-agents.herdr)
          "server"
        ];
        EnvironmentVariables = {
          PATH = "${config.home.profileDirectory}/bin:${lib.makeBinPath agentPackages}:/usr/bin:/bin";
          HERDR_CONFIG_GENERATION = toString config.xdg.configFile."herdr/config.toml".source;
        };
        RunAtLoad = true;
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        ProcessType = "Background";
      };
    };
  };
}
