{ config, lib, ... }:
let
  cfg = config.codgician.services.rustdesk-server;
in
{
  options.codgician.services.rustdesk-server = {
    enable = lib.mkEnableOption "Enable RustDesk.";
  };

  config = lib.mkIf cfg.enable {
    services.rustdesk-server = {
      enable = true;
      openFirewall = true;
      signal = {
        enable = true;
        relayHosts = [ "0.0.0.0" "::" ];
      };
      relay.enable = true;
    };
  };
}
