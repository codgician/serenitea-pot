{ pkgs, ... }:
{
  codgician = {
    services.plasma.wallpaper =
      (pkgs.fetchurl {
        url = "https://web.archive.org/web/20240727142306if_/https://cdn.dynamicwallpaper.club/wallpapers/zt6aeujg1pn/Furina.heic";
        sha256 = "1n8ckyhkbsadilwx171kyw44ivp0z7dhz837p1f5jy3zh811bab6";
      }).outPath;

    system.common.inChina = true;
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      dev = {
        haskell.enable = true;
        rust.enable = true;
      };
      plasma.scale = 2;
    };

    home.packages = with pkgs; [
      screen
      binwalk
    ];
  };

  networking.hostId = "41182c40";

  environment.systemPackages = with pkgs; [
    firefox-bin
    google-chrome
    virt-manager
    kitty
  ];

  system.stateVersion = "26.05";
}
