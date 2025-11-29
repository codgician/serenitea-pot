{ inputs, ... }:

final: prev: {
  disko = inputs.disko.packages.${prev.stdenv.hostPlatform.system}.default;
}
