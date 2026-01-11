{
  config,
  pkgs,
  lib,
  ...
}:
let
  kernelName = "python-base";
  cfg = config.codgician.services.jupyter.extraKernels.${kernelName};
  types = lib.types;
in
{
  options.codgician.services.jupyter.extraKernels.${kernelName} = {
    enable = lib.mkEnableOption "Python base kernel with data science stack";

    pythonPackage = lib.mkOption {
      type = types.package;
      default = pkgs.python3;
      defaultText = lib.literalExpression "pkgs.python3";
      description = "Python package to use for the kernel.";
    };

    extraPackages = lib.mkOption {
      type = types.functionTo (types.listOf types.package);
      default = _: [ ];
      defaultText = lib.literalExpression "ps: []";
      example = lib.literalExpression ''
        ps: with ps; [
          openai
          anthropic
          langchain
        ]
      '';
      description = ''
        Extra Python packages to include beyond the default data science stack.
        The function receives the Python package set and returns a list of packages.

        The base kernel already includes:
        - ipykernel, ipywidgets (Jupyter integration)
        - numpy, pandas, scipy (Data manipulation)
        - matplotlib, seaborn, plotly (Visualization)
        - scikit-learn (Machine learning)
        - torch, transformers (Deep learning)
        - requests, aiohttp (HTTP clients)

        Use this for adding project-specific packages or packages not in the base set.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.jupyter.kernels.${kernelName} =
      let
        pythonEnv = cfg.pythonPackage.withPackages (
          ps:
          with ps;
          [
            # Jupyter integration (REQUIRED)
            ipykernel
            ipywidgets
            jupyter

            # Core data science
            numpy
            pandas
            scipy

            # Visualization
            matplotlib
            seaborn
            plotly

            # Machine learning
            scikit-learn

            # Deep learning
            torch
            torchvision
            transformers
            accelerate
            datasets

            # HTTP clients
            requests
            aiohttp

            # Utilities
            tqdm
            pydantic
            python-dotenv
            rich
          ]
          ++ cfg.extraPackages ps
        );
      in
      {
        displayName = "Python (base)";
        language = "python";
        argv = [
          "${pythonEnv}/bin/python"
          "-m"
          "ipykernel_launcher"
          "-f"
          "{connection_file}"
        ];
        env = {
          PYTHONUNBUFFERED = "1";
        };
      };
  };
}
