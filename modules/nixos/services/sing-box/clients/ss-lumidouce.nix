{ config, lib, ... }:
let
  serviceName = "sing-box";
  profileName = "ss-lumidouce";
  secretName = "sing-ss-lumidouce-password";
  cfg = config.codgician.services.${serviceName};
  clientCfg = cfg.clients.${profileName};
in
{
  options.codgician.services.${serviceName}.clients.${profileName} = {
    enable = lib.mkEnableOption "${profileName} client for ${serviceName}";

    bindInterface = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = "Network interface used for outbound connections.";
    };

    tag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      internal = true;
      default = "outbound-${profileName}";
      description = "Tag name for this outbound.";
    };
  };

  config = lib.mkIf clientCfg.enable {
    services.sing-box.settings = {
      outbounds = [
        {
          type = "shadowsocks";
          tag = clientCfg.tag;
          server = "sz.codgician.me";
          server_port = 3391;
          method = "2022-blake3-aes-256-gcm";
          password._secret = config.codgician.secrets.files.${secretName}.path;
          bind_interface = lib.mkIf (clientCfg.bindInterface != null) clientCfg.bindInterface;
          multiplex = {
            enabled = true;
            protocol = "h2mux";
          };
        }
      ];

      # The lumidouce router, reached through this outbound. DNS queries that
      # enter a TUN routed through lumidouce resolve there as well.
      dns = {
        servers = [
          {
            type = "udp";
            tag = "dns-${profileName}";
            server = "192.168.0.1";
            detour = clientCfg.tag;
          }
        ];
        final = lib.mkIf (cfg.tun.enable && cfg.tun.outbound == clientCfg.tag) "dns-${profileName}";
      };
    };

    codgician.secrets.files.${secretName} = {
      owner = serviceName;
      group = serviceName;
      mode = "0600";
    };
  };
}
