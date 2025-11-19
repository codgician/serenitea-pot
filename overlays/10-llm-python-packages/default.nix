{
  inputs,
  lib,
  system,
  ...
}:

final: prev:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (prev) system;
    config = {
      allowBroken = true;
      allowUnfree = true;
      cudaSupport = lib.systems.inspect.predicates.isLinux system;
      rocmSupport = lib.systems.inspect.predicates.isLinux system;
    };
  };

  # Extension to use specific python packages from unstable
  pythonUnstableExtension =
    pyfinal: pyprev:
    let
      pythonPackagesName = pyprev.python.pythonAttr + "Packages";
    in
    {
      inherit (unstablePkgs.${pythonPackagesName})
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
    };

in
{
  # Non-Python packages pulled directly from unstable
  inherit (unstablePkgs)
    llama-cpp
    ollama
    ollama-cuda
    ollama-rocm
    docling
    docling-serve
    open-webui
    litellm
    vllm
    ;

  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    pythonUnstableExtension
  ];
}
