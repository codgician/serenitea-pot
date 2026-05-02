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

  # Klassy isn't in nixos-25.11-small, so we reuse the unstable channel's
  # *recipe* but build it against this host's stable kdePackages so its
  # Qt ABI matches the running Plasma. Inheriting `prev.unstable.klassy`
  # directly pulls the prebuilt derivation linked against unstable's Qt
  # 6.11, which KWin 6.10 refuses to load with:
  #   "uses incompatible Qt library. (6.11.0) [release]"
  klassy = final.kdePackages.callPackage (
    prev.unstable.path + "/pkgs/by-name/kl/klassy/package.nix"
  ) { };
}
