{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
  serviceName = "litellm";
  cfg = config.codgician.services.litellm;
  types = lib.types;
  allModels = (import ../../../nixos/services/litellm/models.nix { inherit pkgs lib outputs; }).all;
  configFile = (pkgs.formats.yaml { }).generate "config.yaml" {
    model_list = allModels;
  };
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "LiteLLM Proxy.";

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for LiteLLM to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 5483;
      description = ''
        Port for LiteLLM to listen on.
      '';
    };

    package = lib.mkPackageOption pkgs "litellm" { };

    stateDir = lib.mkOption {
      type = types.path;
      default = "/Library/Application Support/litellm";
      description = ''
        Directory for LiteLLM to store state data.
      '';
    };

    keepAlive = lib.mkEnableOption "keeping LiteLLM service alive";
  };

  config = lib.mkIf cfg.enable {
    # Service configurations
    launchd.daemons.${serviceName} = {
      path = [ config.environment.systemPath ];

      environment = {
        "DO_NOT_TRACK" = "True";
        "GITHUB_COPILOT_TOKEN_DIR" = "${cfg.stateDir}/github";
      };

      script = ''
        set -ea
        source ${config.age.secrets.litellm-env.path}
        exec ${lib.getExe cfg.package} --host "${cfg.host}" --port ${builtins.toString cfg.port} --config "${configFile}"
      '';

      serviceConfig = {
        Label = "me.codgician.${serviceName}";
        WorkingDirectory = cfg.stateDir;
        KeepAlive = cfg.keepAlive;
        UserName = "litellm";
        StandardErrorPath = "${cfg.stateDir}/err.log";
        StandardOutPath = "${cfg.stateDir}/out.log";
      };
    };

    # Agenix secret must be readable by the daemon user
    codgician.system.agenix.secrets.litellm-env = {
      owner = serviceName;
    };

    # Ensure directories exist and permissions correct
    system.activationScripts."${serviceName}-prestart".text = ''
      mkdir -p '${cfg.stateDir}/github'
      chown -R ${serviceName}:admin '${cfg.stateDir}'
    '';

    # Ensure system user and group exist for the daemon
    users = {
      knownUsers = [ serviceName ];
      users.${serviceName} = {
        description = "LiteLLM service user";
        isHidden = true;
        createHome = false;
        uid = lib.mkDefault 450;
      };
    };
  };
}
