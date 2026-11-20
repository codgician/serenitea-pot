{ ... }:

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
  # ollama follows `config.cudaSupport`/`rocmSupport` of the unstable set,
  # which inherits them, and takes no override for them.
  inherit (prev.unstable)
    ollama
    ollama-cuda
    ollama-rocm
    ollama-vulkan
    docling
    docling-serve
    litellm
    ;

  llama-cpp = adapt prev.unstable.llama-cpp;

  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    pythonUnstableExtension
  ];
}
