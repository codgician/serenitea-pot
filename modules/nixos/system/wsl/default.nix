{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.system.wsl;
  types = lib.types;
  ldLibraryPath = lib.makeLibraryPath [ pkgs.addOpenGLRunpath.driverLink ];
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
      wslConf.network.generateResolvConf = !config.services.resolved.enable;
    };

    # Disable networkd, resolved and apparmor for compatibility
    networking.useNetworkd = lib.mkForce false;
    services.resolved.enable = lib.mkForce false;
    security.apparmor.enable = lib.mkForce false;

    # Make windows drivers working
    programs.nix-ld = {
      enable = true;
      libraries = config.hardware.graphics.extraPackages;
    };

    # Enable OpenGL
    environment.systemPackages = with pkgs; [
      glxinfo
      vulkan-tools
    ];
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        mesa.drivers
        libvdpau-va-gl
        vaapiVdpau
      ];
    };

    # Hack LD_LIBRARY_PATH
    # See: https://github.com/nix-community/NixOS-WSL/issues/454
    environment.sessionVariables.LD_LIBRARY_PATH = ldLibraryPath;
    services.displayManager.environment.LD_LIBRARY_PATH = ldLibraryPath;
  };
}
