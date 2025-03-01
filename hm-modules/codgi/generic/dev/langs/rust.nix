{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.dev.rust;
in
{
  options.codgician.codgi.dev.rust = {
    enable = lib.mkEnableOption "Rust dev environment.";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      extensions = with pkgs.vscode-marketplace; [
        rust-lang.rust-analyzer
      ];

      userSettings.rust-analyzer.server.path = "rust-analyzer";
    };

    home.packages = with pkgs; [
      rustc
      cargo
      rust-analyzer-unwrapped
    ];
  };
}
