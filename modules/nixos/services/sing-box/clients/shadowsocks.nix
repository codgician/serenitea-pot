{ config, lib, ... }:
let
  profileName = "shadowsocks";
  cfg = config.codgician.services.sing-box;
  clientCfg = cfg.clients.${profileName};
  inherit (lib) types;
in
{
  options.codgician.services.sing-box.clients.${profileName} = {
    enable = lib.mkEnableOption "${profileName} client for sing-box";

    server = lib.mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Server to connect.";
    };

    port = lib.mkOption {
      type = types.port;
      default = cfg.servers.${profileName}.port;
      defaultText = "config.codgician.services.sing-box.servers.shadowsocks.port";
      description = "Port of the remote Shadowsocks server.";
    };

    user = lib.mkOption {
      type = with types; nullOr (enum cfg.users);
      default = null;
      description = "Identity used for accessing server.";
    };

    tag = lib.mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
      default = "outbound-${profileName}";
      description = "Tag name for this outbound.";
    };
  };

  config = lib.mkIf clientCfg.enable {
    services.sing-box.settings.outbounds = [
      {
        type = "shadowsocks";
        tag = clientCfg.tag;
        server = clientCfg.server;
        server_port = clientCfg.port;
        method = "2022-blake3-aes-256-gcm";
        password._secret =
          config.codgician.secrets.templates."sing-${clientCfg.user}-ss-client-password".path;
        multiplex = {
          enabled = true;
          protocol = "h2mux";
        };
      }
    ];

    assertions = [
      {
        assertion = clientCfg.server != null;
        message = "Server must be specified for ${profileName} client.";
      }
      {
        assertion = clientCfg.user != null;
        message = "User must be specified for ${profileName} client.";
      }
    ];
  };
}
