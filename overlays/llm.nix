# Always use ollama from unstable

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
  inherit (unstablePkgs) open-webui;
  inherit (unstablePkgs) llama-cpp vllm;
  inherit (unstablePkgs) ollama ollama-cuda ollama-rocm;
}
// builtins.listToAttrs (
  builtins.map (name: {
    inherit name;
    value = super.${name}.overrideScope (
      ppself: ppsuper: {
        inherit (ppsuper) ollama litellm vllm;
      }
    );
  }) attrs
)
