{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  serviceName = "open-terminal";
  cfg = config.codgician.services.open-terminal;
  dataDir = "/var/lib/open-terminal";
  port = 8022;

  # The container keeps its defaults (0.0.0.0:8000); only the host port is remapped
  settings = {
    api_key._secret = config.codgician.secrets.files.open-terminal-api-key.path;
    multi_user = true;
  };
in
{
  options.codgician.services.open-terminal = {
    enable = lib.mkEnableOption "open-terminal container";

    openFirewall = lib.mkEnableOption "opening firewall for ${serviceName}";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/open-webui/open-terminal:latest";
      description = "Container image for open-terminal.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.open-terminal = {
      autoStart = true;
      inherit (cfg) image;
      ports = [ "127.0.0.1:${toString port}:8000" ];
      volumes = [
        "${dataDir}:/home/user:U"
        "/run/${serviceName}/config.toml:/etc/open-terminal/config.toml:ro"
      ];
      extraOptions = [ "--pull=newer" ];
    };

    virtualisation.podman.enable = true;

    # Generate config.toml with secrets replacement before container starts
    systemd.services.podman-open-terminal = {
      preStart = lib.mkBefore ''
        ${utils.genJqSecretsReplacementSnippet settings "/run/${serviceName}/config.json"}
        ${lib.getExe pkgs.yj} -jt < /run/${serviceName}/config.json > /run/${serviceName}/config.toml
        rm /run/${serviceName}/config.json
      '';
      serviceConfig.RuntimeDirectory = serviceName;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ port ];

    codgician.system.impermanence.extraItems = [
      {
        type = "directory";
        path = dataDir;
      }
    ];
  };
}
