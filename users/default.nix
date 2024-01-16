{ lib, ... }:

let folders = lib.attrsets.filterAttrs (_: type: type == "directory") (builtins.readDir ./.);
in builtins.mapAttrs (folder: _: import ./${folder}) folders
