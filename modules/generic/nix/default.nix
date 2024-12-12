{ config, lib, ... }:
let
  flakePath = lib.codgician.rootDir + "/flake.nix";
  substituters = (import flakePath).nixConfig.extra-substituters;
  trusted-public-keys = (import flakePath).nixConfig.extra-trusted-public-keys;
in
{
  config = lib.mkMerge [
    {
      nix = {
        # Nix garbage collection
        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };

        extraOptions = ''
          experimental-features = nix-command flakes
          accept-flake-config = true
          !include ${config.age.secrets.nixAccessTokens.path}
        '';
        optimise.automatic = true;
        settings = lib.mkMerge [
          {
            inherit substituters trusted-public-keys;
            extra-nix-path = "nixpkgs=flake:nixpkgs";
          }
        ];
      };
    }

    # Agenix secrets
    (with lib.codgician; mkAgenixConfigs { } [ (secretsDir + "/nixAccessTokens.age") ])
  ];
}
