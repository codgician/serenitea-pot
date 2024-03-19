{ lib, ... }:
let
  dirContent = builtins.readDir ./.;
  dirNames = builtins.filter (name: dirContent.${name} == "directory") (builtins.attrNames dirContent);
  allFiles = builtins.concatMap (x: (lib.filesystem.listFilesRecursive ./${x})) dirNames;
  filesToImport = builtins.filter (x: (builtins.baseNameOf x) == "default.nix") allFiles;
in
{
  imports = filesToImport ++ [ ../overlays ../users ];
}
