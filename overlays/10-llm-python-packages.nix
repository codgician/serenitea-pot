# Always use LLM packages from unstable

{ inputs, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
    };
  };

  pythonNames = builtins.filter (x: builtins.match "(^python[0-9]*$)" x != null) (
    builtins.attrNames super
  );

  mkPackageOverride =
    pythonPackagesName:
    (ppself: ppsuper: {
      inherit (unstablePkgs.${pythonPackagesName})
        ollama
        litellm
        vllm
        ;
    });
in
{
  inherit (unstablePkgs) litellm;
  inherit (unstablePkgs) llama-cpp vllm;
  inherit (unstablePkgs) ollama ollama-cuda ollama-rocm;
}
# Override python packages
// builtins.listToAttrs (
  builtins.map (pythonName: {
    name = pythonName;
    value = super.${pythonName}.override {
      packageOverrides = mkPackageOverride (super.${pythonName}.pythonAttr + "Packages");
    };
  }) pythonNames
)
