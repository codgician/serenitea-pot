{ ... }:

final: prev:
let
  mkEnvWrappedApplication =
    package: envFile:
    final.writeShellApplication {
      name = package.meta.mainProgram;
      runtimeInputs = [ package ];
      text = ''
        set -a
        eval "$(sudo cat ${envFile})"
        set +a
        exec ${package.meta.mainProgram} "$@"
      '';
      inherit (package) meta;
    }
    // {
      inherit (package) version;
    };
in
{
  # Env bundles are sops-nix host templates, rendered at activation to
  # /run/secrets/rendered/<name> (see modules/nixos/system/secrets).
  claude-code-wrapped = mkEnvWrappedApplication final.claude-code "/run/secrets/rendered/claude-code-env";
  codex-wrapped = mkEnvWrappedApplication final.codex "/run/secrets/rendered/codex-env";
  droid-wrapped = mkEnvWrappedApplication final.nur.repos.codgician.droid "/run/secrets/rendered/droid-env";
}
