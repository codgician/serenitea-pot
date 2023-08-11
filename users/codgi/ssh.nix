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
      "pilot" = {
        hostname = "pilot.lan";
        user = "codgi";
      };
    };
  };
}
