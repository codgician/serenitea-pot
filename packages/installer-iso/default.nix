{ lib, ... }:

let
  # Caution: produced iso should NEVER contain any secrets
  mkNixOsInstallerIso = pkgs: (lib.nixosSystem {
    inherit (pkgs) system;
    specialArgs = { inherit lib pkgs; };
    modules = [
      ({ pkgs, modulesPath, ... }: {
        imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
        environment.systemPackages = with pkgs; [ agenix disko vim ];
      })
    ];
  }).config.system.build.isoImage;
in
lib.codgician.forLinuxSystems mkNixOsInstallerIso
