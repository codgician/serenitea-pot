{ ... }:

final: prev: let 
  mkEnvWrappedApplication = package: envFile: final.writeShellApplication {
    name = package.meta.mainProgram;
    runtimeInputs = [ package ];
    text = ''
      set -a
      eval "$(sudo cat ${envFile})"
      set +a
      exec ${package.meta.mainProgram} "$@"
    '';
    inherit (package) meta;
  };
in {
  claude-code-wrapped = mkEnvWrappedApplication final.claude-code "/run/agenix/claude-code-env";
}
