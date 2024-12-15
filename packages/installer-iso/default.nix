{ lib, outputs, ... }:

# Caution: produced iso should NEVER contain any secrets
lib.codgician.forLinuxSystems (pkgs: (
  let
    inherit (pkgs) system;
    hostDrvs = lib.pipe (outputs.nixosConfigurations) [
      (lib.filterAttrs (k: v: v.pkgs.system == pkgs.system && builtins.hasAttr "disko" v.config && v.config.disko.devices.disk != { }))
      (lib.mapAttrs (k: v: v.config.system.build.toplevel))
      (builtins.attrValues)
    ];
  in
  lib.codgician.mkNixosSystem {
    hostName = "nixos";
    modules = [
      ({ modulesPath, ... }: {
        imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
        environment.systemPackages = hostDrvs;
      })
    ];
    inherit system;
  }
).config.system.build.isoImage)
