{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.common;
in
{
  config = lib.mkIf cfg.enable {
    # Enable nix daemon
    services.nix-daemon.enable = true;
  };
}
