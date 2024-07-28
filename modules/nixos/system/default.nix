{ lib, ... }: {
  imports = lib.codgician.getFolderPaths ./.;
}
