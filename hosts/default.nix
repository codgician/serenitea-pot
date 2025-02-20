{ outputs, ... }:

let
  inherit (outputs) lib libUnstable;
  getConfigurations =
    path:
    lib.pipe path [
      (lib.codgician.getFolderNames)
      (builtins.map (name: {
        inherit name;
        value = import (path + "/${name}") { inherit lib libUnstable; };
      }))
      builtins.listToAttrs
    ];
in
{
  darwinConfigurations = getConfigurations ./darwin;
  nixosConfigurations = getConfigurations ./nixos;
}
