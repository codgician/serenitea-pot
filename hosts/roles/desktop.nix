{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.codgician.services.plasma) wallpaper;
in
{
  codgician = {
    services = {
      fcitx5.enable = true;
      plasma.enable = true;
    };

    system.common.audio.enable = true;
  };

  home-manager.users.codgi.codgician.codgi = {
    mcp.enable = true;
    oh-my-pi.enable = true;
    plasma.wallpaper = lib.mkIf (wallpaper != null) wallpaper;
    vscode.enable = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = lib.mkDefault "nixos-bgrt";
    themePackages = lib.mkIf (config.boot.plymouth.theme == "nixos-bgrt") [
      pkgs.nixos-bgrt-plymouth
    ];
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
  };

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  # Already set by the common module; the second definition repeats both
  # entries in nix.conf.
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  zramSwap.enable = true;
}
