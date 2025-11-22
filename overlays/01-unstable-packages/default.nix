{ ... }:

final: prev: {
  inherit (prev.unstable)
    sing-box
    sing-geoip
    nexttrace
    codex
    claude-code
    antigravity
    zfs_unstable
    ;
}
