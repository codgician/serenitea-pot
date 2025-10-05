{ config, lib, ... }:
let
  profileName = "hysteria2";
  cfg = config.codgician.services.sing-box;
  clientCfg = cfg.clients.${profileName};
  serverCfg = cfg.servers.${profileName};
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

    user = lib.mkOption {
      type = with types; nullOr (enum cfg.users);
      default = null;
      description = "Identity used for accessing server.";
    };

    downMbps = lib.mkOption {
      type = with types; nullOr int;
      default = null;
      description = "Max download bandwidth in Mbps.";
    };

    upMbps = lib.mkOption {
      type = with types; nullOr int;
      default = null;
      description = "Max upload bandwidth in Mbps.";
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
      rec {
        type = "hysteria2";
        tag = clientCfg.tag;
        server = lib.codgician.getHostFqdn clientCfg.server;
        server_port = serverCfg.publicPort;
        password._secret = config.age.secrets."sing-${clientCfg.user}-proxy-password".path;
        down_mbps = lib.mkIf (clientCfg.downMbps != null) clientCfg.downMbps;
        up_mbps = lib.mkIf (clientCfg.upMbps != null) clientCfg.upMbps;
        hop_interval = "30s";
        brutal_debug = false;

        tls = {
          enabled = true;
          alpn = [ "h3" ];
          insecure = false;
          server_name = server;
          ech = {
            enabled = true;
            config_path = ./ech.configs;
          };
          utls = {
            enabled = true;
            fingerprint = "random";
          };
        };
      }
    ];

    assertions = [
      {
        assertion = !clientCfg.enable || clientCfg.server != null;
        message = "Server must be specified for ${profileName} client.";
      }
      {
        assertion = !clientCfg.enable || clientCfg.user != null;
        message = "User must be specified for ${profileName} client.";
      }
    ];
  };
}
