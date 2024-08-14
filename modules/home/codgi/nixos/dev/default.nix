{ lib, ... }: {
  imports = lib.codgician.getNixFilePaths ./langs;
}