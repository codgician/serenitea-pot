{ ... }:

final: prev: {
  claude-code-wrapped = final.writeShellApplication {
    name = "claude";
    runtimeInputs = [ final.claude-code ];
    text = ''
      set -a
      eval "$(sudo cat /run/agenix/claude-code-env)"
      set +a
      exec claude "$@"
    '';
    meta = final.claude-code.meta;
  };
}
