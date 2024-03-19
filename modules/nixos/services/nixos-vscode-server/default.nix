{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.nixos-vscode-server;
in
{
  options.codgician.services.nixos-vscode-server = {
    enable = lib.mkEnableOption "Enable NixOS VSCode Server support.";
  };

  config = lib.mkIf cfg.enable {
    services.vscode-server.enable = true;
  };
}
