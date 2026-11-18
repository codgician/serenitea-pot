{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.system.wsl;
  ldLibraryPath = lib.makeLibraryPath [ pkgs.addDriverRunpath.driverLink ];

  # See: https://github.com/nix-community/NixOS-WSL/issues/454
  env = {
    LD_LIBRARY_PATH = ldLibraryPath;
    GALLIUM_DRIVER = "d3d12";
    LIBGL_KOPPER_DRI2 = "true";
  };
in
{
  options.codgician.system.wsl.enable = lib.mkEnableOption "NixOS WSL";

  config = lib.mkIf cfg.enable {
    wsl = {
      enable = true;
      defaultUser = "codgi";
      docker-desktop.enable = true;
      ssh-agent.enable = true;
      interop.register = true;
      usbip.enable = true;
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
      mesa-demos
      vulkan-tools
    ];

    hardware.graphics.enable = true;

    environment.sessionVariables = env;
    services.displayManager.generic.environment = env;
  };
}
