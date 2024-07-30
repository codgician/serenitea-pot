{ lib, ... }: rec {
  # Path to root
  rootDir = ../.;

  # Path to modules folder
  modulesDir = rootDir + "/modules";

  # Path to overlays folder
  overlaysDir = rootDir + "/overlays";

  # List all item names with specified type under specified path 
  getDirContentByType = type: path:
    let dirContent = if lib.pathIsDirectory path then builtins.readDir path else { };
    in builtins.filter (name: dirContent.${name} == type) (builtins.attrNames dirContent);

  # Get all folder names under specified path
  getFolderNames = getDirContentByType "directory";

  # Get all folder full paths under specified path
  getFolderPaths = path: builtins.map (x: path + "/${x}") (getFolderNames path);

  # Get all regular file names under specified path
  getRegularFileNames = getDirContentByType "regular";

  # Get all regular file full paths under specified path
  getRegularFilePaths = path: builtins.map (x: path + "/${x}") (getRegularFileNames path);

  # Get all nix file names under specified path
  getNixFileNames = path: builtins.filter (lib.hasSuffix ".nix") (getRegularFileNames path);

  # Get all nix file full paths under specified path
  getNixFilePaths = path: builtins.map (x: path + "/${x}") (getNixFileNames path);
}
