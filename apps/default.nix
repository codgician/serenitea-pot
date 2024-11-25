args @ { lib, ... }:
let
  attrs = builtins.map
    (name: builtins.mapAttrs
      (k: v: { "${name}" = v; })
      (import ./${name} args))
    (lib.codgician.getFolderNames ./.);
in
builtins.foldl' lib.attrsets.recursiveUpdate { } attrs
