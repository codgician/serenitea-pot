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
  cfg = config.codgician.system.nix;
in
{
  options.codgician.system.nix = {
    useCnMirror = lib.mkEnableOption "China mainland mirror for nix binary cache";
  };

  config = lib.mkMerge [
    {
      nix = {
        # Use latest nix
        package = pkgs.nixVersions.latest;

        # Nix garbage collection
        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };

        extraOptions =
          ''
            fallback = true
            experimental-features = nix-command flakes
            accept-flake-config = true
          ''
          + (lib.optionalString (config.age.secrets ? "nix-access-tokens") ''
            !include ${config.age.secrets.nix-access-tokens.path}
          '');
        optimise.automatic = true;
        settings = lib.mkMerge [
          {
            inherit trusted-public-keys;
            substituters =
              (lib.optionals cfg.useCnMirror [
                "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10"
              ])
              ++ substituters;
            extra-nix-path = "nixpkgs=flake:nixpkgs";
          }
        ];
      };

      environment.systemPackages = with pkgs; [
        nix-eval-jobs
        nix-fast-build
      ];

      # Agenix secrets
      codgician.system.agenix.secrets.nix-access-tokens.mode = "0644";
    }
  ];
}
