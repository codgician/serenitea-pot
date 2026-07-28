# Temporarily unblock cuda build as seen in https://github.com/NixOS/nixpkgs/issues/544701
# TODO: remove after fix PR https://github.com/NixOS/nixpkgs/pull/545542 merged upstream

{ lib, ... }:

let
  cudaFix = _final: prev: {
    cudaPackages = prev.cudaPackages.overrideScope (
      _cFinal: cPrev: {
        setupCudaHook = cPrev.pkgs.makeSetupHook {
          name = "setup-cuda-hook";

          substitutions.setupCudaHook = placeholder "out";

          # Required in addition to ccRoot as otherwise bin/gcc is looked up
          # when building CMakeCUDACompilerId.cu
          substitutions.ccFullPath = "${cPrev.backendStdenv.cc}/bin/${cPrev.backendStdenv.cc.targetPrefix}c++";

          meta.license = lib.licenses.mit;
        } ./setup-cuda-hook.sh;
      }
    );
  };
in
final: prev:
(cudaFix final prev)
// {
  # `prev.unstable` is imported separately, so local overlays do not reach it.
  unstable = prev.unstable.extend cudaFix;
}
