{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.wsl;
in
{
  options.codgician.system.wsl = {
    enable = lib.mkEnableOption "Enable NixOS WSL.";
  };

  config = lib.mkIf cfg.enable {
    wsl.enable = true;
    networking.useNetworkd = lib.mkForce false;
    services.resolved.enable = lib.mkForce false;
  };
}
