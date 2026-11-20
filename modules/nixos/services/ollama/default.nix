{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "ollama";
  cfg = config.codgician.services.ollama;
  types = lib.types;
in
{
  options.codgician.services.ollama = {
    enable = lib.mkEnableOption "Ollama";

    acceleration = lib.mkOption {
      type = types.nullOr (
        types.enum [
          false
          "cuda"
          "rocm"
          "vulkan"
        ]
      );
      default = null;
      description = "Acceleration backend for ollama; selects the default package.";
    };

    package = lib.mkPackageOption pkgs "ollama" {
      default = if builtins.isString cfg.acceleration then "ollama-${cfg.acceleration}" else "ollama";
      extraDescription = "Defaults to the `ollama` variant built for `acceleration`.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/ollama";
      description = "Directory for ollama to store data.";
    };

    modelDir = lib.mkOption {
      type = types.path;
      default = "${cfg.dataDir}/models";
      defaultText = lib.literalExpression ''"''${dataDir}/models"'';
      description = "Directory for ollama to store models.";
    };

    loadModels = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Download these models using `ollama pull` as soon as ollama.service has started.
        Search for models of your choice from: https://ollama.com/library
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      host = "127.0.0.1";
      port = 11434;
      user = serviceName;
      group = serviceName;
      inherit (cfg) package loadModels;
      home = cfg.dataDir;
      models = cfg.modelDir;
      environmentVariables = {
        OLLAMA_FLASH_ATTENTION = lib.mkIf (cfg.acceleration != false) "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0";
        OLLAMA_NEW_ENGINE = "1";
        # Increase default context length to 32K
        OLLAMA_CONTEXT_LENGTH = "32768";
        # Keep alive
        OLLAMA_KEEP_ALIVE = "-1";
      };
    };
  };
}
