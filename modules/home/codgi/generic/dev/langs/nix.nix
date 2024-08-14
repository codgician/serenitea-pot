{ config, osConfig, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.dev.nix;
  types = lib.types;
in
{
  options.codgician.codgi.dev.nix = {
    enable = lib.mkEnableOption "Enable nix dev environment.";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
      ];

      userSettings = {
        "[nix]".editor.tabSize = 2;
        nix.serverPath = "${pkgs.nil}/bin/nil";
      };
    };
  };
}
