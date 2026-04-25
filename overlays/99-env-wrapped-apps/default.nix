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
  claude-code-wrapped = mkEnvWrappedApplication final.claude-code "/run/agenix/claude-code-env";
  codex-wrapped = mkEnvWrappedApplication final.codex "/run/agenix/codex-env";
  droid-wrapped = mkEnvWrappedApplication final.nur.repos.codgician.droid "/run/agenix/droid-env";
}
