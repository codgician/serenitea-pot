{ config, lib, pkgs, ... }: {

  programs.ssh = {
    enable = true;
    extraConfig = ''
      AddKeysToAgent yes
    '' + lib.optionalString pkgs.stdenvNoCC.isDarwin ''
      IgnoreUnknown UseKeychain
      UseKeychain yes
      IdentityFile ~/.ssh/id_ed25519
    '';
    matchBlocks = {
      "focalors" = {
        hostname = "focalors.lan";
        user = "codgi";
      };
      "furina" = {
        hostname = "furina.lan";
        user = "codgi";
      };
      "paimon" = {
        hostname = "paimon.lan";
        user = "codgi";
      };
      "violet" = {
        hostname = "violet.lan";
        user = "codgi";
      };
      "panther" = {
        hostname = "panther.lan";
        user = "codgi";
      };
      "openwrt" = {
        hostname = "openwrt.lan";
        user = "root";
      };
      "nanopi" = {
        hostname = "nanopi.cdu";
        user = "root";
      };
    };
  };
}
