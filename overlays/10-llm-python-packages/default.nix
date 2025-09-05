# Always use LLM packages from unstable

{
  inputs,
  lib,
  system,
  ...
}:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
    config = {
      allowUnfree = true;
      cudaSupport = lib.systems.inspect.predicates.isLinux system;
      rocmSupport = lib.systems.inspect.predicates.isLinux system;
    };
  };

  pythonNames = builtins.filter
    (x: builtins.match "(^python[0-9]*$)" x != null)
    (builtins.attrNames super);

  # Produce a patched pythonPackages set (keeping override methods intact)
  mkPatchedPythonPackages =
    pp:
    pp.override {
      overrides = pself': ppsuper': {
        docling-serve =
          let
            orig = ppsuper'.docling-serve;
            mkPatched = pkg:
              pkg.overridePythonAttrs (old: {
                pythonRemoveDeps = (old.pythonRemoveDeps or []) ++ [ "docling-mcp" ];
              });
          in
          # Reattach / wrap override + overrideDerivation so downstream usage
          # (including the one inside the application package) still works
          mkPatched orig // {
            override = args: mkPatched (orig.override args);
            overrideDerivation = f: mkPatched (orig.overrideDerivation f);
          };
      };
    };

  mkPackageOverride =
    pythonPackagesName:
    (ppself: ppsuper: {
      inherit (mkPatchedPythonPackages unstablePkgs.${pythonPackagesName})
        rapidocr-onnxruntime
        onnxruntime
        docling
        docling-ibm-models
        docling-core
        docling-parse
        docling-serve
        ollama
        litellm
        vllm
        ;
    });
in
{
  # Non-Python packages pulled directly from unstable
  inherit (unstablePkgs) llama-cpp;
  inherit (unstablePkgs) ollama ollama-cuda ollama-rocm;
}
# Override Python applications to use patched python3Packages
// (lib.genAttrs
  [ "docling" "docling-serve" "open-webui" "litellm" "vllm" ]
  (pkgName:
    unstablePkgs.${pkgName}.override {
      python3Packages = mkPatchedPythonPackages unstablePkgs.python3Packages;
    })
)
# Override each pythonXY interpreter to expose unstable + patched packages
// builtins.listToAttrs (
  builtins.map (pythonName: {
    name = pythonName;
    value = super.${pythonName}.override {
      packageOverrides = mkPackageOverride (super.${pythonName}.pythonAttr + "Packages");
    };
  }) pythonNames
)