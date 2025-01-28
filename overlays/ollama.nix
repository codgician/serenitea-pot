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
  inherit (unstablePkgs) ollama ollama-cuda ollama-rocm;
}
// builtins.listToAttrs (
  builtins.map (name: {
    inherit name;
    value = super.${name}.overrideScope (
      ppself: ppsuper: {
        ollama = ppsuper.ollama;
        litellm = ppsuper.litellm;
      }
    );
  }) attrs
)
