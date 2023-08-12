{ config, lib, pkgs, ... }: {

  programs.ssh = {
    enable = true;
    extraConfig = ''
      AddKeysToAgent yes
    '' + lib.optionalString pkgs.stdenvNoCC.isDarwin ''
      IgnoreUnknown UseKeychain
      UseKeychain yes
    '';
    matchBlocks = {
      "openwrt" = {
        hostname = "openwrt.lan";
        user = "root";
      };
      "pilot" = {
        hostname = "pilot.lan";
        user = "codgi";
      };
      "media" = {
        hostname = "media.lan";
        user = "codgi";
      };
    };
  };
}
