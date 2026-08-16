{
  config,
  lib,
  pkgs,
  ...
}:
let
  flakePath = lib.codgician.rootDir + "/flake.nix";
  substituters = (import flakePath).nixConfig.extra-substituters;
  trusted-public-keys = (import flakePath).nixConfig.extra-trusted-public-keys;
in
{
  config = {
    nix = {
      # Use latest nix
      package = pkgs.nixVersions.latest;

      # Nix garbage collection
      gc = {
        automatic = true;
        options = "--delete-older-than 7d";
      };

      extraOptions = ''
        fallback = true
        experimental-features = nix-command flakes
        accept-flake-config = true
      ''
      + (lib.optionalString (config.codgician.secrets.templates ? "nix-access-tokens") ''
        !include ${config.codgician.secrets.templates.nix-access-tokens.path}
      '');
      optimise.automatic = true;
      settings = {
        inherit trusted-public-keys;
        substituters =
          (lib.optionals config.codgician.system.common.inChina [
            "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10"
          ])
          ++ substituters;
        extra-nix-path = "nixpkgs=flake:nixpkgs";
      };
    };

    environment.systemPackages = with pkgs; [
      nix-eval-jobs
      nix-fast-build
    ];
  };
}
