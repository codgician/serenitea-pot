{ config, lib, ... }:
let
  cfg = config.codgician.services.sing-box;
  domain = "${config.networking.hostName}.${lib.codgician.inventory.zone}";
  certDir = config.security.acme.certs.${domain}.directory;
  port = 8443;
in
{
  options.codgician.services.sing-box.servers.hysteria2.enable =
    lib.mkEnableOption "hysteria2 server for sing-box";

  config = lib.mkIf cfg.servers.hysteria2.enable {
    services.sing-box.settings.inbounds = [
      {
        type = "hysteria2";
        tag = "inbound-hysteria2";
        listen = "::";
        listen_port = port;
        brutal_debug = false;

        masquerade = {
          type = "proxy";
          url = "https://127.0.0.1";
        };

        tls = {
          enabled = true;
          alpn = [ "h3" ];
          server_name = domain;
          certificate_path = certDir + "/fullchain.pem";
          key_path = certDir + "/key.pem";
          ech = {
            enabled = true;
            key_path = config.codgician.secrets.files."sing-ech-keys".path;
          };
        };

        users = builtins.map (name: {
          inherit name;
          password._secret = config.codgician.secrets.files."sing-${name}-password".path;
        }) cfg.users;
      }
    ];

    codgician.acme.${domain}.enable = true;

    networking.firewall = {
      allowedTCPPorts = [ port ];
      allowedUDPPorts = [ port ];
    };
  };
}
