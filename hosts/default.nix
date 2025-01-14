{ outputs, ... }:

let
  inherit (outputs) lib libUnstable;
  configurations = lib.pipe (lib.codgician.getFolderNames ./.) [
    (builtins.map (name: {
      inherit name;
      value = import ./${name} { inherit lib libUnstable; };
    }))
    builtins.listToAttrs
  ];
in
{
  darwinConfigurations = lib.filterAttrs (
    k: v: lib.codgician.isDarwinSystem v.pkgs.system
  ) configurations;
  nixosConfigurations = lib.filterAttrs (
    k: v: lib.codgician.isLinuxSystem v.pkgs.system
  ) configurations;
}
