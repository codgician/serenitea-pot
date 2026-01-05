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
    ;
}
