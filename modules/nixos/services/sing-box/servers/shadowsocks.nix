{ config, lib, ... }:
let
  cfg = config.codgician.services.sing-box;
  port = 8444;
in
{
  options.codgician.services.sing-box.servers.shadowsocks.enable =
    lib.mkEnableOption "shadowsocks server for sing-box";

  config = lib.mkIf cfg.servers.shadowsocks.enable {
    services.sing-box.settings.inbounds = [
      {
        type = "shadowsocks";
        tag = "inbound-shadowsocks";
        listen = "::";
        listen_port = port;
        method = "2022-blake3-aes-256-gcm";
        password._secret = config.codgician.secrets.files.sing-ss-password.path;
        users = builtins.map (name: {
          inherit name;
          password._secret = config.codgician.secrets.files."sing-${name}-ss-password".path;
        }) cfg.users;
        multiplex.enabled = true;
      }
    ];

    codgician.secrets.files =
      lib.genAttrs ([ "sing-ss-password" ] ++ builtins.map (name: "sing-${name}-ss-password") cfg.users)
        (_: {
          owner = "sing-box";
          group = "sing-box";
          mode = "0600";
        });

    networking.firewall = {
      allowedTCPPorts = [ port ];
      allowedUDPPorts = [ port ];
    };
  };
}
