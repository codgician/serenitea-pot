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
    }
    // (lib.genAttrs [ "vllm" ] (name: adapt prev.unstable.${pythonPackagesName}.${name}));
in
{
  # Non-Python packages pulled directly from unstable
  inherit (prev.unstable)
    ollama-cuda
    ollama-rocm
    ollama-vulkan
    docling
    docling-serve
    litellm
    ;

  # Override open-webui to use rapidocr-onnxruntime with tests disabled
  open-webui = prev.unstable.open-webui.override {
    python3Packages = prev.unstable.python3Packages.overrideScope (
      pyFinal: pyPrev: {
        rapidocr-onnxruntime = pyPrev.rapidocr-onnxruntime.overridePythonAttrs (_: {
          doCheck = false;
        });
      }
    );
  };

  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    pythonUnstableExtension
  ];
}
// (lib.genAttrs [
  "ollama"
  "llama-cpp"
  "vllm"
] (name: adapt prev.unstable.${name}))
