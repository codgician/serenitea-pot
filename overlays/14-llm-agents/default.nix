{ inputs, system, ... }:

final: _prev: {
  llm-agents =
    let
      packages = inputs.llm-agents.packages.${system} or { };
    in
    packages
    // final.lib.optionalAttrs (packages ? herdr-app && final.stdenv.hostPlatform.isLinux) {
      # zstd-sys links the system libzstd, which upstream omits from buildInputs on Linux.
      herdr-app = packages.herdr-app.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ final.zstd ];
      });
    };
}
