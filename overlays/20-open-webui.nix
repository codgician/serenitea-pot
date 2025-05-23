# Always use open-webui from unstable

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

  python3Packages = unstablePkgs.python3Packages.override {
    # Not needed after https://github.com/NixOS/nixpkgs/pull/408208 gets merged
    overrides = ppself: ppsuper: {
      rapidocr-onnxruntime = ppsuper.rapidocr-onnxruntime.overridePythonAttrs (_: {
        doCheck = false;
      });
    };
  };
in
{
  open-webui =
    (unstablePkgs.open-webui.override {
      inherit python3Packages;
    }).overridePythonAttrs
      (oldAttrs: {
        dependencies = oldAttrs.dependencies ++ [
          python3Packages.torchWithCuda
        ];
      });
}
