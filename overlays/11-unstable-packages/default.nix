{ ... }:

final: prev: {
  inherit (prev.unstable)
    prl-tools
    sing-box
    sing-geoip
    nexttrace
    beads
    codex
    claude-code
    antigravity
    zfs_unstable
    matrix-tuwunel
    open-webui
    azure-artifacts-credprovider
    git-credential-manager
    looking-glass-client
    pi-coding-agent
    ;

  # opencode is a Bun single-file executable. Bun's `--compile` emits a fragile
  # ad-hoc code signature whose CDHash does not match the binary, so on
  # aarch64-darwin the kernel rejects it ("invalid signature (code or signature
  # have been modified)") and kills the process with SIGKILL ("Killed: 9") before
  # it prints anything. (Upstream's cached build slips through because its CI
  # builders relax AMFI enforcement.) Re-sign the compiled binary with a valid
  # ad-hoc signature right after Bun emits it, before opencode's own build-time
  # smoke test (and the runtime) execute it.
  opencode = prev.unstable.opencode.overrideAttrs (
    oldAttrs:
    prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
      # sigtool's codesign delegates Mach-O signature-space allocation to
      # codesign_allocate, which is not on PATH inside the build sandbox.
      env = (oldAttrs.env or { }) // {
        CODESIGN_ALLOCATE = "${prev.darwin.cctools}/bin/codesign_allocate";
      };

      postPatch = (oldAttrs.postPatch or "") + ''
        substituteInPlace packages/opencode/script/build.ts \
          --replace-fail \
            '// Smoke test: only run if binary is for current platform' \
            'await $`${prev.darwin.sigtool}/bin/codesign --force --sign - dist/''${name}/bin/opencode`
            // Smoke test: only run if binary is for current platform'
      '';
    }
  );

  # Bump github-copilot-cli to the latest upstream release
  github-copilot-cli =
    let
      inherit (prev.unstable) github-copilot-cli;
      version = "1.0.55";
    in
    if github-copilot-cli.version >= version then
      github-copilot-cli
    else
      prev.unstable.github-copilot-cli.overrideAttrs (oldAttrs: rec {
        inherit version;
        src = prev.unstable.fetchurl {
          url = "https://github.com/github/copilot-cli/releases/download/v${version}/github-copilot-${version}.tgz";
          hash = "sha256-ENzY5ZG4ZEx5KbuIpJ44NAgtcVDi70wHnlYeO0wshBQ=";
        };

        # Starting with 1.0.40+, the upstream tarball ships musl-libc prebuilds of
        # keytar (`prebuilds/linuxmusl-{x64,arm64}/keytar.node`). On glibc NixOS
        # auto-patchelf cannot resolve `libc.musl-x86_64.so.1` for those binaries
        # and fails the build. We don't need them - the matching glibc prebuilds
        # are also shipped and get patched correctly - so strip them out.
        preFixup = (oldAttrs.preFixup or "") + ''
          rm -rf "$out"/lib/github-copilot-cli/prebuilds/linuxmusl-*
        '';
      });
}
