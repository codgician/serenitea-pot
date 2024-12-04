{ config, lib, ... }:
let
  cfg = config.codgician.services.open-webui;
  types = lib.types;
  listToStr = lib.strings.concatStringsSep ";";

  litellmEnable = config.codgician.services.litellm.enable;
  litellmHost = config.codgician.services.litellm.host;
  litellmPort = config.codgician.services.litellm.port;
  litellmBases = lib.optionals litellmEnable [ "http://${litellmHost}:${builtins.toString litellmPort}" ];
  litellmKeys = lib.optionals litellmEnable [ "dummy" ];
in
{
  options.codgician.services.open-webui = {
    enable = lib.mkEnableOption "Enable open-webui.";

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for open-webui to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 3010;
      description = ''
        Port for open-webui to listen on.
      '';
    };

    openFirewall = lib.mkEnableOption "Open firewall for open-webui.";

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Enable reverse proxy for open-webui.";

      favicon = lib.mkOption {
        type = types.nullOr types.path;
        example = "/path/to/favicon.png";
        default = null;
        description = ''
          Path to the customized favicon.png file.
        '';
      };

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [ "example.com" "example.org" ];
        default = [ ];
        description = ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://${cfg.host}:${builtins.toString cfg.port}";
        defaultText = ''http://$\{config.codgician.services.open-webui.host\}:$\{toString config.codgician.services.open-webui.port\}'';
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.open-webui = {
        enable = true;
        inherit (cfg) host port openFirewall;
        environmentFile = config.age.secrets.openWebuiEnv.path;
        environment = {
          WEBUI_AUTH = "True";
          WEBUI_NAME = "Akasha";
          WEBUI_URL =
            if cfg.reverseProxy.enable
            then builtins.head cfg.reverseProxy.domains
            else "${cfg.host}:${builtins.toString cfg.port}";
          ENABLE_SIGNUP = "False";
          ENABLE_LOGIN_FORM = "True";
          DEFAULT_USER_ROLE = "pending";
          ENABLE_OLLAMA_API = if config.services.ollama.enable then "True" else "False";
          OLLAMA_BASE_URL = lib.mkIf config.services.ollama.enable (
            let
              ollamaHost = config.services.ollama.host;
              ollamaPort = config.services.ollama.port;
            in
            "http://${ollamaHost}:${builtins.toString ollamaPort}"
          );
          ENABLE_OPENAI_API = "True";
          OPENAI_API_BASE_URLS = listToStr litellmBases;
          OPENAI_API_KEYS = listToStr litellmKeys;
          ENABLE_SEARCH_QUERY = "True";
          ENABLE_RAG_WEB_SEARCH = "True";
          RAG_WEB_SEARCH_ENGINE = "google_pse";
        };
      };
    })

    (lib.mkIf cfg.enable
      (with lib.codgician; mkAgenixConfigs { } [ (secretsDir + "/openWebuiEnv.age") ]))

    # Reverse proxy profile
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.open-webui = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
          };
          locations."=/static/favicon.png" = with cfg.reverseProxy; lib.mkIf (favicon != null) { alias = favicon; };
        };
      };
    })
  ];
}
