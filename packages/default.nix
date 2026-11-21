args@{
  lib,
  pkgs,
  system,
  ...
}:
let
  # Decided from the system string alone: listing package names must not
  # instantiate nixpkgs, since nix probes `packages.<system>` to resolve every
  # installable, including `.#nixosConfigurations.<host>`.
  unsupportedSystems = {
    docs-darwin = [ "x86_64-darwin" ];
    docs-nixos = [ "x86_64-darwin" ];
    installer-iso = lib.codgician.darwinSystems;
    installer-iso-gui = lib.codgician.darwinSystems;
  };
  callPackage = lib.callPackageWith (pkgs // mypkgs);
  mypkgs = lib.pipe (builtins.readDir ./.) [
    (lib.filterAttrs (
      name: type: type == "directory" && !(builtins.elem system (unsupportedSystems.${name} or [ ]))
    ))
    (lib.mapAttrs (name: _: callPackage ./${name} args))
  ];
in
mypkgs
