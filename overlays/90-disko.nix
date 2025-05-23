{ inputs, ... }:

self: super: {
  disko = inputs.disko.packages.${super.system}.default;
}
