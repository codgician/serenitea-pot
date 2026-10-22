{ inputs, system, ... }:

_final: prev:
let
  packages = inputs.llm-agents.packages.${system} or { };
in
{
  llm-agents =
    packages
    // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
      # patchelf 0.19.2 makes Copilot 1.0.101 segfault; stable 0.15.2 preserves it.
      copilot-cli = packages.copilot-cli.override { inherit (prev) patchelf; };
    };
}
