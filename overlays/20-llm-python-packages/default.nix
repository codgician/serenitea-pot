{ lib, fromUnstable, ... }:

lib.composeManyExtensions [
  (fromUnstable [
    "ollama"
    "ollama-cuda"
    "ollama-rocm"
    "ollama-vulkan"
    "docling"
    "docling-serve"
    "litellm"
    "llama-cpp"
  ])

  (fromUnstable.python [
    "docling"
    "docling-ibm-models"
    "docling-core"
    "docling-parse"
    "docling-serve"
    "ollama"
    "litellm"
  ])
]
