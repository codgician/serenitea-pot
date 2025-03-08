{ inputs, lib, ... }:

self: super:
let
  isAttr = x: lib.hasPrefix "python" x && lib.hasSuffix "Packages" x;
  attrs = builtins.filter isAttr (builtins.attrNames super);
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
    config.allowUnfree = true;
  };
in
{
  # Always use LLM related packages from unstable
  inherit (unstablePkgs) open-webui;
  inherit (unstablePkgs) llama-cpp vllm;
  inherit (unstablePkgs) ollama ollama-cuda ollama-rocm;
}
// builtins.listToAttrs (
  # Always python package universe from unstable
  builtins.map (name: {
    inherit name;
    value = unstablePkgs.${name};
  }) attrs
)
