{ lib, ... }: rec {
  # Concat attributes
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;

  # List all item names with specified type under specified path 
  getDirContentByType = type: path:
    let dirContent = builtins.readDir path;
    in builtins.filter (name: dirContent.${name} == type) (builtins.attrNames dirContent);

  # List all folder names under specified path
  getFolderNames = getDirContentByType "directory";

  # List all regular file names under specified path
  getRegularFileNames = getDirContentByType "regular";

  # Get default.nix under specified path recursively
  getImports = path:
    let
      dirNames = getFolderNames path;
      allFiles = builtins.concatMap (x: (lib.filesystem.listFilesRecursive (path + "/${x}"))) dirNames;
    in
    builtins.filter (x: (builtins.baseNameOf x) == "default.nix") allFiles;
}
