{ config, lib, ... }:
let
  profileName = "hysteria2";
  cfg = config.codgician.services.sing-box;
  serverCfg = cfg.servers.${profileName};
  inherit (lib) types;
  certDir = config.security.acme.certs."${cfg.domain}".directory;
in
{
  options.codgician.services.sing-box.servers.${profileName} = {
    enable = lib.mkEnableOption "${profileName} server for sing-box";

    users = lib.mkOption {
      type = with types; listOf (enum cfg.users);
      default = cfg.users;
      defaultText = "config.codgician.services.sing-box.users";
      description = ''
        List of user names that can access this server.
        should exist under secrets folder.
      '';
    };

    ip = lib.mkOption {
      type = types.str;
      default = "::";
      description = "IP address that this server listens on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8443;
      description = "Port that this server listens on.";
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

    openFirewall = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports.";
    };

    publicPort = lib.mkOption {
      type = types.port;
      readOnly = true;
      internal = true;
      default = serverCfg.port;
      description = "Public port that users connect to for this profile.";
    };

    tag = lib.mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
      default = "inbound-${profileName}";
      description = "Tag name for this inbound.";
    };
  };

  config = lib.mkIf serverCfg.enable {
    services.sing-box.settings.inbounds = [
      {
        type = "hysteria2";
        tag = serverCfg.tag;
        listen = serverCfg.ip;
        listen_port = serverCfg.port;
        down_mbps = lib.mkIf (serverCfg.downMbps != null) serverCfg.downMbps;
        up_mbps = lib.mkIf (serverCfg.upMbps != null) serverCfg.upMbps;
        brutal_debug = false;

        masquerade = {
          type = "proxy";
          url = "https://127.0.0.1";
        };

        tls = {
          enabled = true;
          alpn = [ "h3" ];
          server_name = cfg.domain;
          certificate_path = certDir + "/fullchain.pem";
          key_path = certDir + "/key.pem";
          ech = {
            enabled = true;
            key_path = config.age.secrets."sing-ech-keys".path;
          };
        };

        users = builtins.map (name: {
          inherit name;
          password._secret = config.age.secrets."sing-${name}-proxy-password".path;
        }) serverCfg.users;
      }
    ];

    # Open firewall
    networking.firewall = lib.mkIf serverCfg.openFirewall {
      allowedTCPPorts = [ serverCfg.port ];
      allowedUDPPorts = [ serverCfg.port ];
    };
  };
}
