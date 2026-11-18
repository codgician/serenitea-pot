{ inputs, system, ... }:

final: _prev: {
  llm-agents =
    let
      packages = inputs.llm-agents.packages.${system} or { };
      codexNeedsOpenSSL =
        packages ? codex
        && final.lib.any (
          dep:
          (dep.pname or null) == "aws-lc" && !(final.lib.elem "openssl" (dep.meta.pkgConfigModules or [ ]))
        ) packages.codex.buildInputs
        && !(final.lib.any (dep: (dep.pname or null) == "openssl") packages.codex.buildInputs);
    in
    packages
    // final.lib.optionalAttrs (packages ? herdr-app && final.stdenv.hostPlatform.isLinux) {
      # zstd-sys links the system libzstd, which upstream omits from buildInputs on Linux.
      herdr-app = packages.herdr-app.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ final.zstd ];
      });
    }
    // final.lib.optionalAttrs codexNeedsOpenSSL {
      # Prefixed AWS-LC no longer provides openssl.pc for openssl-sys.
      codex = packages.codex.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ final.openssl ];
      });
    };
}
