{
  config,
  pkgs,
  lib,
  utils,
  ...
}:
let
  serviceName = "mcpo";
  inherit (lib) types;
  cfg = config.codgician.containers.mcpo;
  mcpoConfig.mcpServers = {
    arxiv = {
      command = "uv";
      args = [
        "tool"
        "run"
        "arxiv-mcp-server"
        "--storage-path"
        "/persist/arxiv"
      ];
    };
    amap-maps = {
      command = "npx";
      args = [
        "-y"
        "@amap/amap-maps-mcp-server"
      ];
      env.AMAP_MAPS_API_KEY._secret = config.age.secrets.mcp-amap-api-key.path;
    };
    code-runner = {
      type = "streamable_http";
      url = "https://cpprunner.aiursoft.cn/mcp";
      headers = {
        "Content-Type" = "application/json";
      };
    };
    context7 = {
      command = "npx";
      args = [
        "-y"
        "@upstash/context7-mcp"
      ];
      env.DEFAULT_MINIMUM_TOKENS = "10000";
    };
    fetch = {
      command = "uvx";
      args = [ "mcp-server-fetch" ];
    };
    google-maps = {
      command = "npx";
      args = [
        "-y"
        "@modelcontextprotocol/server-google-maps"
      ];
      env.GOOGLE_MAPS_API_KEY._secret = config.age.secrets.mcp-google-maps-api-key.path;
    };
    sequential-thinking = {
      command = "npx";
      args = [
        "-y"
        "@modelcontextprotocol/server-sequential-thinking"
      ];
    };
    time = {
      command = "uvx";
      args = [
        "mcp-server-time"
        "--local-timezone=${config.time.timeZone}"
      ];
    };
  };
in
{
  options.codgician.containers.mcpo = {
    enable = lib.mkEnableOption "mcpo container";

    port = lib.mkOption {
      type = types.port;
      default = 8010;
      description = "Port for mcpo to listen on.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/mcpo";
      description = "Data directory for mcpo.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.containers.mcpo; http://127.0.0.1:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.mcpo = {
        autoStart = true;
        image = "ghcr.io/open-webui/mcpo:latest";
        ports = [ "127.0.0.1:${builtins.toString cfg.port}:8000" ];
        volumes = [
          "/run/mcpo/config.json:/config.json"
          "${cfg.dataDir}:/persist"
        ];
        extraOptions = [ "--pull=newer" ];
        cmd = [ "--config=/config.json" ];
      };

      virtualisation.podman.enable = true;

      # Compose config.json before container starts
      systemd.services.podman-mcpo = {
        path = with pkgs; [ curl ];
        preStart = lib.mkBefore ''
          ${utils.genJqSecretsReplacementSnippet mcpoConfig "/run/mcpo/config.json"}
        '';
        postStart = ''
          curl --fail \
            --retry 100 \
            --retry-delay 5 \
            --retry-max-time 300 \
            --retry-all-errors \
            http://127.0.0.1:${builtins.toString cfg.port}/openapi.json
        '';
        serviceConfig.RuntimeDirectory = serviceName;
      };
    })

    # Agenix secrets
    (lib.mkIf cfg.enable (
      with lib.codgician;
      mkAgenixConfigs { } (
        builtins.map getAgeSecretPathFromName [
          "mcp-amap-api-key"
          "mcp-google-maps-api-key"
        ]
      )
    ))

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
