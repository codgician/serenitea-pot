{ inputs, mkLib, ... }:

let
  lib = mkLib inputs.nixpkgs;
  libUnstable = mkLib inputs.nixpkgs-nixos-unstable;
  configurations = lib.pipe (lib.codgician.getFolderNames ./.) [
    (builtins.map (x: (import ./${x}) // { hostName = x; }))
    (builtins.filter (x: !x?enable || x.enable))
    (builtins.map (host: {
      name = host.hostName;
      value =
        let
          lib' = if (host?stable && !host.stable) then libUnstable else lib;
          builder =
            if (lib.codgician.isDarwinSystem host.system)
            then lib'.codgician.mkDarwinSystem
            else lib'.codgician.mkNixosSystem;
        in
        builder host;
    }))
    builtins.listToAttrs
  ];
in
{
  darwinConfigurations = lib.filterAttrs (k: v: lib.codgician.isDarwinSystem v.pkgs.system) configurations;
  nixosConfigurations = lib.filterAttrs (k: v: lib.codgician.isLinuxSystem v.pkgs.system) configurations;
}
