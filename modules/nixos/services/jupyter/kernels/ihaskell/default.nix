{
  config,
  pkgs,
  lib,
  ...
}:
let
  kernelName = "ihaskell";
  cfg = config.codgician.services.jupyter.extraKernels.${kernelName};
  types = lib.types;
in
{
  options.codgician.services.jupyter.extraKernels.${kernelName} = {
    enable = lib.mkEnableOption "IHaskell kernel";

    package = lib.mkPackageOption pkgs "ihaskell" { };

    extraPackages = lib.mkOption {
      type = types.functionTo (types.listOf types.package);
      default = _: [ ];
      defaultText = lib.literalExpression "ps: []";
      example = lib.literalExpression ''
        ps: with ps; [
          lens
          aeson
          vector
          ihaskell-hvega
        ]
      '';
      description = ''
        Extra Haskell packages available in the IHaskell kernel.
        The function receives the Haskell package set and returns a list of packages.

        Note: The base ihaskell package already includes ihaskell-blaze and
        ihaskell-diagrams for basic visualization support.

        Common useful packages:
        - Data manipulation: lens, aeson, vector, containers, text, bytestring
        - Visualization: ihaskell-hvega, hvega, diagrams, diagrams-cairo
        - Web/HTTP: wreq, http-client, http-client-tls, servant
        - Math/Science: statistics, scientific, hmatrix
        - Utilities: mtl, transformers, unordered-containers, time
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.jupyter.kernels.${kernelName} =
      let
        # Check if custom packages are requested
        hasExtraPackages = cfg.extraPackages pkgs.haskellPackages != [ ];

        # Override ihaskell with custom packages if provided
        ihaskellWithPackages =
          if hasExtraPackages then
            cfg.package.override { packages = cfg.extraPackages; }
          else
            cfg.package;
      in
      {
        displayName = "Haskell";
        language = "haskell";
        argv = [
          (lib.getExe' ihaskellWithPackages "ihaskell")
          "kernel"
          "{connection_file}"
        ];
      };
  };
}
