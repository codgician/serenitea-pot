{ config, ... }:
let
  domain = "hass.codgician.me";
  port = 8123;
in
{
  services.home-assistant = {
    enable = true;
    configDir = "/mnt/data/hass";
    configWritable = false;
    openFirewall = true;
    extraComponents = [
      "backup"
      "default_config"
      "esphome"
      "met"
      "homekit"
      "homekit_controller"
      "wake_on_lan"
      "xbox"
      "xiaomi"
      "xiaomi_aqara"
      "xiaomi_ble"
      "xiaomi_miio"
      "xiaomi_tv"
      "yeelight"
    ];
    config = {
      http = {
        server_host = "::1";
        trusted_proxies = [ "::1" ];
        use_x_forwarded_for = true;
        server_port = port;
      };
      default_config = { };
      homeassistant = {
        name = "Suzhou";
        unit_system = "metric";
        time_zone = "Asia/Shanghai";
        temperature_unit = "C";
      };
    };
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    locations."/" = {
      proxyPass = "http://[::1]:${builtins.toString port}";
      proxyWebsockets = true;
    };

    forceSSL = true;
    http2 = true;
    enableACME = true;
    acmeRoot = null;
    extraConfig = ''
      proxy_buffering off;
    '';
  };

  # SSL certificate
  security.acme.certs."${domain}" = {
    inherit domain;
    extraDomainNames = [
      "sz.codgician.me"
      "sz4.codgician.me"
      "sz6.codgician.me"
    ];
    group = config.services.nginx.user;
  };
}
