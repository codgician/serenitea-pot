{ ... }:

final: prev: {
  inherit (prev.unstable)
    prl-tools
    sing-box
    sing-geoip
    nexttrace
    zfs_unstable
    matrix-tuwunel
    looking-glass-client
    ;
}
