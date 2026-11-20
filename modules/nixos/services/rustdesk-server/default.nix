{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.rustdesk-server;
in
{
  options.codgician.services.rustdesk-server = {
    enable = lib.mkEnableOption "RustDesk";
    package = lib.mkPackageOption pkgs "rustdesk-server" { };
  };

  config = lib.mkIf cfg.enable {
    services.rustdesk-server = {
      enable = true;
      inherit (cfg) package;
      openFirewall = true;
      signal = {
        enable = true;
        relayHosts = [
          "0.0.0.0"
          "::"
        ];
      };
      relay.enable = true;
    };

    # Persist data directory (keypairs, etc.)
    codgician.system.impermanence.extraItems = [
      {
        type = "directory";
        path = "/var/lib/rustdesk-server";
      }
    ];
  };
}
