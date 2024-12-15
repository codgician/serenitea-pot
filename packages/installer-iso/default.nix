{ lib, outputs, ... }:

# Caution: produced iso should NEVER contain any secrets
lib.codgician.forLinuxSystems (pkgs: (
  let
    hostDirvs = lib.pipe (outputs.nixosConfigurations) [
      (lib.filterAttrs (k: v: v.pkgs.system == pkgs.system && builtins.hasAttr "disko" v.config && v.config.disko.devices.disk != { }))
      (lib.mapAttrs (k: v: v.config.system.build.toplevel))
      (builtins.attrValues)
    ];
  in
  lib.nixosSystem {
    inherit (pkgs) system;
    specialArgs = { inherit lib pkgs; };
    modules = [
      outputs.modules.nixos
      ({ pkgs, modulesPath, ... }: {
        imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
        environment.systemPackages = with pkgs; [ agenix disko vim ] ++ hostDirvs;
      })
    ];
  }
).config.system.build.isoImage)
