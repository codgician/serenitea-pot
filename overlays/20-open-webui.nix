# Use open-webui from unstable and apply patches

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
    (unstablePkgs.open-webui.override { inherit python3Packages; }).overridePythonAttrs
      (_: {
        patches = [
          # Add fish-speech support (#11230)
          (super.fetchurl {
            url = "https://patch-diff.githubusercontent.com/raw/open-webui/open-webui/pull/11230.patch";
            sha256 = "sha256-JD498hMgJGnWCdFSPppVrXjrpR8nRXDMPm/BXo+V03M=";
          })
        ];
      });
}
