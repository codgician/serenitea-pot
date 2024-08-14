{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.common;
in
{
  options.codgician.system.common = {
    enable = lib.mkOption {
      default = true;
      description = "Enable common options shared accross all systems.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix = {
      extraOptions = "experimental-features = nix-command flakes repl-flake";
      settings = {
        extra-nix-path = "nixpkgs=flake:nixpkgs";
        auto-optimise-store = true;
      };
    };
  };
}
