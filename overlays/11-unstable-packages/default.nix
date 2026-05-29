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
    opencode
    antigravity
    zfs_unstable
    matrix-tuwunel
    open-webui
    azure-artifacts-credprovider
    git-credential-manager
    looking-glass-client
    pi-coding-agent
    ;

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
