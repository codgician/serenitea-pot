{ ... }:

final: prev: {
  inherit (prev.unstable)
    prl-tools
    sing-box
    sing-geoip
    nexttrace
    codex
    claude-code
    antigravity
    zfs_unstable
    ;
}
