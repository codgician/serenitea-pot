{ config, lib, ... }:
let
  profileName = "shadowsocks";
  cfg = config.codgician.services.sing-box;
  serverCfg = cfg.servers.${profileName};
  inherit (lib) types;
in
{
  options.codgician.services.sing-box.servers.${profileName} = {
    enable = lib.mkEnableOption "${profileName} server for sing-box";

    users = lib.mkOption {
      type = with types; listOf (enum cfg.users);
      default = cfg.users;
      defaultText = "config.codgician.services.sing-box.users";
      description = "List of user names that can access this server.";
    };

    ip = lib.mkOption {
      type = types.str;
      default = "::";
      description = "IP address that this server listens on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8388;
      description = "Port that this server listens on.";
    };

    openFirewall = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports.";
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
        type = "shadowsocks";
        tag = serverCfg.tag;
        listen = serverCfg.ip;
        listen_port = serverCfg.port;
        method = "2022-blake3-aes-256-gcm";
        password._secret = config.codgician.secrets.files.sing-ss-password.path;
        users = builtins.map (name: {
          inherit name;
          password._secret = config.codgician.secrets.files."sing-${name}-ss-password".path;
        }) serverCfg.users;
        multiplex.enabled = true;
      }
    ];

    codgician.secrets.files =
      lib.genAttrs
        ([ "sing-ss-password" ] ++ builtins.map (name: "sing-${name}-ss-password") serverCfg.users)
        (_: {
          owner = "sing-box";
          group = "sing-box";
          mode = "0600";
        });

    networking.firewall = lib.mkIf serverCfg.openFirewall {
      allowedTCPPorts = [ serverCfg.port ];
      allowedUDPPorts = [ serverCfg.port ];
    };
  };
}
