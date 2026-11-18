{ pkgs, ... }:
{
  codgician.system = {
    common.inChina = true;
    secure-boot.enable = false;
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      claude-code.enable = true;
      dev = {
        haskell.enable = true;
        rust.enable = true;
      };
      herdr.enable = true;
      plasma.scale = 1;
    };

    home.packages = with pkgs; [
      binwalk
    ];
  };

  boot.plymouth.theme = "breeze";

  environment.systemPackages = with pkgs; [
    firefox-bin
    google-chrome
    kitty
  ];

  system.stateVersion = "26.05";
}
