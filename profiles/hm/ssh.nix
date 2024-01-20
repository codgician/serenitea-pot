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
      "openwrt" = {
        hostname = "openwrt.lan";
        user = "root";
      };
      "mona" = {
        hostname = "mona.lan";
        user = "codgi";
      };
      "violet" = {
        hostname = "violet.lan";
        user = "codgi";
      };
      "macrun" = {
        hostname = "macrun.lan";
        user = "runner";
      };
      "nanopi" = {
        hostname = "nanopi.cdu";
        user = "root";
      };
    };
  };
}
