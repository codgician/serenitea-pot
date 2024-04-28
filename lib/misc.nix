{ lib, ... }: rec {
  # Concat attributes
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;

  # List all folder names under specified path
  getFolderNames = path:
    let
      dirContent = builtins.readDir path;
    in
    builtins.filter (name: dirContent.${name} == "directory") (builtins.attrNames dirContent);

  # Get default.nix under specified path recursively
  getImports = path:
    let
      dirNames = getFolderNames path;
      allFiles = builtins.concatMap (x: (lib.filesystem.listFilesRecursive (path + "/${x}"))) dirNames;
    in
    builtins.filter (x: (builtins.baseNameOf x) == "default.nix") allFiles;
}
