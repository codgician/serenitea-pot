{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) types;

  kind = "ihaskell";
  cfg = config.codgician.services.jupyter.kernels.${kind};

  enabledKernels = lib.filterAttrs (_: icfg: icfg.enable) cfg;

  # Upstream kernel id, prefixed by kind to avoid collisions across kinds.
  mkId = name: "${kind}-${name}";

  mkKernel =
    name: icfg:
    let
      # Override ihaskell with custom packages only when some are requested.
      hasExtraPackages = icfg.extraPackages pkgs.haskellPackages != [ ];
      ihaskell =
        if hasExtraPackages then icfg.package.override { packages = icfg.extraPackages; } else icfg.package;
    in
    lib.nameValuePair (mkId name) {
      inherit (icfg) displayName;
      language = "haskell";
      argv = [
        (lib.getExe' ihaskell "ihaskell")
        "kernel"
        "{connection_file}"
      ];
      env = icfg.env;
    };
in
{
  options.codgician.services.jupyter.kernels.${kind} = lib.mkOption {
    default = { };
    description = ''
      IHaskell Jupyter kernels. Each attribute defines an independent instance
      (declare several to deploy multiple Haskell kernels with different package
      sets on one machine). The attribute name is the instance name; the
      resulting Jupyter kernel id is `ihaskell-<name>`.
    '';
    example = lib.literalExpression ''
      {
        default = {
          enable = true;
          extraPackages = ps: with ps; [ lens aeson vector ];
        };
      }
    '';
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkEnableOption "this IHaskell kernel instance";

            displayName = lib.mkOption {
              type = types.str;
              default = "Haskell (${name})";
              defaultText = lib.literalExpression ''"Haskell (<name>)"'';
              description = "Human-readable name shown in the Jupyter kernel picker.";
            };

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
                Extra Haskell packages available in this IHaskell instance.
                The function receives the Haskell package set and returns a list
                of packages.

                Note: The base ihaskell package already includes ihaskell-blaze
                and ihaskell-diagrams for basic visualization support.

                Common useful packages:
                - Data manipulation: lens, aeson, vector, containers, text, bytestring
                - Visualization: ihaskell-hvega, hvega, diagrams, diagrams-cairo
                - Web/HTTP: wreq, http-client, http-client-tls, servant
                - Math/Science: statistics, scientific, hmatrix
                - Utilities: mtl, transformers, unordered-containers, time
              '';
            };

            env = lib.mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Extra environment variables written to this kernel's kernel.json.";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (enabledKernels != { }) {
    services.jupyter.kernels = lib.mapAttrs' mkKernel enabledKernels;

    assertions = lib.mapAttrsToList (name: _: {
      assertion = builtins.match "[A-Za-z0-9._-]+" name != null;
      message = "jupyter: IHaskell kernel instance name '${name}' must match [A-Za-z0-9._-]+.";
    }) enabledKernels;
  };
}
