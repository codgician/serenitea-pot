{ inputs, ... }:

final: prev: {
  disko = inputs.disko.packages.${prev.system}.default;
}
