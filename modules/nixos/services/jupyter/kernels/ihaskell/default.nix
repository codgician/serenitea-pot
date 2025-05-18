{
  config,
  pkgs,
  lib,
  ...
}:
let
  kernelName = "ihaskell";
  cfg = config.codgician.services.jupyter.extraKernels.${kernelName};
in
{
  options.codgician.services.jupyter.extraKernels.${kernelName} = {
    enable = lib.mkEnableOption "IHaskell kernel";
    package = lib.mkPackageOption pkgs "ihaskell" { };
  };

  config = lib.mkIf cfg.enable {
    services.jupyter.kernels.${kernelName} = {
      displayName = "Haskell";
      language = "haskell";
      argv = [
        (lib.getExe' cfg.package "ihaskell")
        "kernel"
        "{connection_file}"
      ];
    };
  };
}
