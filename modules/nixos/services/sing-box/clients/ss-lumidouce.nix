{ config, lib, ... }:
let
  profileName = "ss-lumidouce";
  secretName = "sing-ss-lumidouce-password";
  cfg = config.codgician.services.sing-box;
  clientCfg = cfg.clients.${profileName};
  tag = "outbound-${profileName}";
in
{
  options.codgician.services.sing-box.clients.${profileName} = {
    enable = lib.mkEnableOption "${profileName} client for sing-box";

    bindInterface = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = "Network interface used for outbound connections.";
    };
  };

  config = lib.mkIf clientCfg.enable {
    services.sing-box.settings = {
      outbounds = [
        {
          type = "shadowsocks";
          inherit tag;
          server = lib.codgician.published.wireguard.lumidouce.domain;
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
      # enter the TUN, which routes through lumidouce, resolve there as well.
      dns = {
        servers = [
          {
            type = "udp";
            tag = "dns-${profileName}";
            server = "192.168.0.1";
            detour = tag;
          }
        ];
        final = lib.mkIf cfg.tun.enable "dns-${profileName}";
      };
    };

    codgician.secrets.files.${secretName} = {
      owner = "sing-box";
      group = "sing-box";
      mode = "0600";
    };
  };
}
