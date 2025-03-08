# Always use LLM packages from unstable

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
        inherit (unstablePkgs.${name})
          ollama
          vllm
          ;

        # Temporary: override litellm to a newer version
        litellm = unstablePkgs.${name}.litellm.overrideAttrs (old: rec {
          version = "1.61.7";
          src = unstablePkgs.fetchFromGitHub {
            owner = "BerriAI";
            repo = "litellm";
            tag = "v${version}";
            hash = "sha256-kXCkei2f0GNm/XEOTcJ5WtZIwWaLNGYsN6fwvtHJiFo=";
          };
        });
      }
    );
  }) attrs
)
