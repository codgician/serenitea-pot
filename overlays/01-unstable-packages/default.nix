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
    github-copilot-cli
    antigravity
    zfs_unstable
    matrix-tuwunel
    open-webui
    azure-artifacts-credprovider
    git-credential-manager
    looking-glass-client
    ;
}
