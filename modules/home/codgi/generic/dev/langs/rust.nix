{ config, osConfig, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.dev.rust;
  types = lib.types;
in
{
  options.codgician.codgi.dev.rust = {
    enable = lib.mkEnableOption "Enable rust dev environment.";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      extensions = with pkgs.vscode-extensions; [
        rust-lang.rust-analyzer
      ];

      userSettings.rust-analyzer.server.path =
        "${pkgs.rust-analyzer-unwrapped}/bin/rust-analyzer";
    };

    home.packages = with pkgs; [
      rustc
      cargo
    ];
  };
}
