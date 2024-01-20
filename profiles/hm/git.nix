{ config, lib, pkgs, ... }: {

  programs.git = {
    enable = true;
    lfs.enable = true;
    package = pkgs.gitFull;

    userName = "codgician";
    userEmail = "15964984+codgician@users.noreply.github.com";

    extraConfig.credential.helper = lib.mkIf (pkgs.stdenvNoCC.isDarwin) "osxkeychain";
  };
}
