{ lib, ... }:

final: prev:
let
  # Helper to apply host config to an unstable package
  adapt =
    pkg:
    pkg.override {
      cudaSupport = prev.config.cudaSupport or false;
      rocmSupport = prev.config.rocmSupport or false;
    };

  # Extension to use specific python packages from unstable
  pythonUnstableExtension =
    pyfinal: pyprev:
    let
      pythonPackagesName = pyprev.python.pythonAttr + "Packages";
    in
    {
      inherit (prev.unstable.${pythonPackagesName})
        docling
        docling-ibm-models
        docling-core
        docling-parse
        docling-serve
        ollama
        litellm
        ;
    };
in
{
  inherit (prev.unstable)
    ollama-cuda
    ollama-rocm
    ollama-vulkan
    docling
    docling-serve
    litellm
    ;

  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    pythonUnstableExtension
  ];
}
// (lib.genAttrs [
  "ollama"
  "llama-cpp"
] (name: adapt prev.unstable.${name}))
