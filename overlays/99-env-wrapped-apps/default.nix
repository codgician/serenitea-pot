{ ... }:

final: prev:
let
  mkEnvWrappedApplication =
    package: template:
    final.writeShellApplication {
      name = package.meta.mainProgram;
      runtimeInputs = [ package ];
      text = ''
        set -a
        eval "$(sudo cat '/run/secrets/rendered/${template}')"
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
  # /run/secrets/rendered/<name> (see modules/generic/system/secrets).
  claude-code-wrapped = mkEnvWrappedApplication final.claude-code "claude-code-env";
  codex-wrapped = mkEnvWrappedApplication final.codex "codex-env";
  droid-wrapped = mkEnvWrappedApplication final.nur.repos.codgician.droid "droid-env";
  opencode-wrapped = mkEnvWrappedApplication final.opencode "opencode-env";
}
