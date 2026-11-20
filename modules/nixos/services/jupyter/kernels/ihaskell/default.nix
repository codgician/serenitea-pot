{
  config,
  pkgs,
  lib,
  ...
}:
let
  # text, bytestring, containers, mtl, transformers and time are GHC core
  # libraries; ihaskell-blaze and ihaskell-diagrams come with ihaskell.
  ihaskell = config.codgician.services.jupyter.kernels.ihaskell.package.override {
    packages =
      ps: with ps; [
        lens
        lens-aeson
        aeson
        vector

        # Data visualization
        ihaskell-hvega
        hvega
        diagrams
        diagrams-cairo
        diagrams-svg

        # Web & HTTP
        wreq
        http-client
        http-client-tls

        # Scientific computing
        statistics
        scientific

        # Utilities
        unordered-containers
        hashable
        uuid
      ];
  };
in
{
  options.codgician.services.jupyter.kernels.ihaskell = {
    enable = lib.mkEnableOption "this IHaskell kernel instance";
    package = lib.mkPackageOption pkgs "ihaskell" { };
  };

  config =
    lib.mkIf
      (
        config.codgician.services.jupyter.enable
        && config.codgician.services.jupyter.kernels.ihaskell.enable
      )
      {
        services.jupyter.kernels.ihaskell-default = {
          displayName = "Haskell (default)";
          language = "haskell";
          argv = [
            (lib.getExe' ihaskell "ihaskell")
            "kernel"
            "{connection_file}"
          ];
          env = { };
        };
      };
}
