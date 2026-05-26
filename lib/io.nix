{ lib, ... }:
rec {
  # List all item names with specified type under specified path
  getDirContentByType =
    type: path:
    let
      dirContent = if lib.pathIsDirectory path then builtins.readDir path else { };
    in
    builtins.filter (name: dirContent.${name} == type) (builtins.attrNames dirContent);

  # Get all folder names under specified path
  getFolderNames = getDirContentByType "directory";

  # Get all folder full paths under specified path
  getFolderPaths = path: builtins.map (x: path + "/${x}") (getFolderNames path);

  # Build an attrset of `folderName -> folderPath` for each subdirectory.
  mapFolders =
    path:
    builtins.listToAttrs (
      builtins.map (name: {
        inherit name;
        value = path + "/${name}";
      }) (getFolderNames path)
    );

  # Merge `mapFolders` results from multiple source paths (right wins).
  mergeFolders = paths: builtins.foldl' (acc: p: acc // mapFolders p) { } paths;

  # Get all regular file names under specified path
  getRegularFileNames = getDirContentByType "regular";

  # Get all regular file full paths under specified path
  getRegularFilePaths = path: builtins.map (x: path + "/${x}") (getRegularFileNames path);

  # Get all nix file names under specified path
  getNixFileNames = path: builtins.filter (lib.hasSuffix ".nix") (getRegularFileNames path);

  # Get all nix file names under specified path without extension
  getNixFileNamesWithoutExt = path: builtins.map (lib.removeSuffix ".nix") (getNixFileNames path);

  # Get all nix file full paths under specified path
  getNixFilePaths = path: builtins.map (x: path + "/${x}") (getNixFileNames path);
}
