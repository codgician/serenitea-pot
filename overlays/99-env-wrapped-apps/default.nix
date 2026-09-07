{ lib, ... }:

final: prev:
let
  mkEnvWrappedApplication =
    package: template:
    let
      mainProgram = package.meta.mainProgram;
      envFile = "/run/secrets/rendered/${template}";
      loadEnv = ''
        set -a
        eval "$(sudo cat ${lib.escapeShellArg envFile})"
        set +a
      '';
    in
    package.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];
      postFixup = (old.postFixup or "") + ''
        wrapProgram "$out/bin/${mainProgram}" \
          --run ${lib.escapeShellArg loadEnv}
      '';
    });
in
{
  # Env bundles are sops-nix host templates, rendered at activation to
  # /run/secrets/rendered/<name> (see modules/generic/system/secrets).
  chatgpt-wrapped = mkEnvWrappedApplication final.llm-agents.chatgpt "codex-env";
  codex-wrapped = mkEnvWrappedApplication final.llm-agents.codex "codex-env";
  droid-wrapped = mkEnvWrappedApplication final.llm-agents.droid "droid-env";
}
