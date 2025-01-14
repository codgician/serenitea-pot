args@{ lib, ... }:
let
  attrs = builtins.map (name: builtins.mapAttrs (k: v: { "${name}" = v; }) (import ./${name} args)) (
    lib.codgician.getFolderNames ./.
  );
  limit =
    path: lhs: rhs:
    (builtins.length path) >= 2;
in
builtins.foldl' (lib.attrsets.recursiveUpdateUntil limit) { } attrs
