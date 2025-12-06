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
  cfg = config.codgician.services.mcpo;
  mcpoConfig.mcpServers = {
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
      headers."Content-Type" = "application/json";
    };
    context7 = {
      type = "streamable_http";
      url = "https://mcp.context7.com/mcp";
      headers.CONTEXT7_API_KEY._secret = config.age.secrets.context7-api-key.path;
    };
    fetch = {
      command = "uvx";
      args = [
        "mcp-server-fetch"
        "--ignore-robots-txt"
        "--user-agent=\"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36\""
      ];
    };
    google-maps = {
      command = "npx";
      args = [
        "-y"
        "@modelcontextprotocol/server-google-maps"
      ];
      env.GOOGLE_MAPS_API_KEY._secret = config.age.secrets.mcp-google-maps-api-key.path;
    };
    github = {
      type = "streamable_http";
      url = "https://api.githubcopilot.com/mcp/";
      headers.Authorization._secret = config.age.secrets.github-auth-header.path;
    };
    paper-search = {
      command = "uv";
      args = [
        "tool"
        "run"
        "--from"
        "paper-search-mcp"
        "python"
        "-m"
        "paper_search_mcp.server"
      ];
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
  options.codgician.services.mcpo = {
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
      defaultProxyPassText = ''with config.codgician.services.mcpo; http://127.0.0.1:$\{toString port}'';
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

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
