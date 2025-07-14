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
        rapidocr-onnxruntime
        onnxruntime
        docling
        docling-ibm-models
        docling-serve
        docling-core
        docling-parse
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

  docling = unstablePkgs.docling.override {
    python3Packages = unstablePkgs.python3Packages;
  };
  docling-serve = unstablePkgs.docling-serve.override {
    python3Packages = unstablePkgs.python3Packages;
  };
  open-webui = unstablePkgs.open-webui.override {
    python3Packages = unstablePkgs.python3Packages;
  };
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
