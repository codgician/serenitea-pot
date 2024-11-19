{ inputs, ... }:

self: super: {
  agenix = inputs.agenix.packages.${super.system}.default;
}
