{ inputs, ... }:

final: prev: {
  agenix = inputs.agenix.packages.${prev.system}.default;
}
