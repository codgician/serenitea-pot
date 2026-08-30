{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.codgi.herdr;
  agentPackages = [
    cfg.package
  ]
  ++ lib.optionals (config.codgician.codgi.claude-code.enable or false) [
    config.codgician.codgi.claude-code.package
  ]
  ++ lib.optionals (config.codgician.codgi.codex.enable or false) [
    config.codgician.codgi.codex.package
  ]
  ++ lib.optionals (config.codgician.codgi.droid.enable or false) [
    config.codgician.codgi.droid.package
  ]
  ++ lib.optionals (config.codgician.codgi.github-copilot-cli.enable or false) [
    config.codgician.codgi.github-copilot-cli.package
  ]
  ++ lib.optionals (config.codgician.codgi.oh-my-pi.enable or false) [
    config.codgician.codgi.oh-my-pi.package
  ]
  ++ lib.optionals (config.codgician.codgi.opencode.enable or false) [
    config.codgician.codgi.opencode.package
  ]
  ++ lib.optionals (config.codgician.codgi.pi-coding-agent.enable or false) [
    config.codgician.codgi.pi-coding-agent.package
  ];
in
{
  config = lib.mkIf cfg.enable {
    launchd.agents.herdr = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe cfg.package)
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
