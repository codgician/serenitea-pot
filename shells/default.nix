args@{ lib, ... }: lib.genAttrs (lib.codgician.getFolderNames ./.) (name: import ./${name} args)
