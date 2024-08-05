{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.wsl;
  types = lib.types;
in
{
  options.codgician.system.wsl = {
    enable = lib.mkEnableOption "Enable NixOS WSL.";

    defaultUser = lib.mkOption {
      type = types.str;
      description = "Default user when launching NixOS WSL.";
    };
  };

  config = lib.mkIf cfg.enable {
    wsl = { 
      inherit (cfg) enable defaultUser; 
      useWindowsDriver = true;
      nativeSystemd = true;
      wslConf.network.generateResolvConf = !config.services.resolved.enable;
    };

    # Disable networkd and resolved for compatibility
    networking.useNetworkd = lib.mkForce false;
    services.resolved.enable = lib.mkForce false;

    # Make windows drivers working
    programs.nix-ld = {
      enable = true;
      libraries = config.hardware.opengl.extraPackages;
    };
  };
}
