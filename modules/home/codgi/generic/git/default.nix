{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.git;
in
{
  options.codgician.codgi.git.enable = lib.mkEnableOption "Enable git user configurations.";

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      lfs.enable = true;
      package = pkgs.gitFull;

      userName = "codgician";
      userEmail = "15964984+codgician@users.noreply.github.com";

      extraConfig.credential.helper = lib.mkIf (pkgs.stdenvNoCC.isDarwin) "osxkeychain";
    };
  };
}
