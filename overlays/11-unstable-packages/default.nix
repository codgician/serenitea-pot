{ ... }:

final: prev: {
  # Patch the one package without `extend`, which would instantiate the whole
  # unstable package set a second time.
  unstable = prev.unstable // {
    # cargoSetupHook requires system AWS-LC for aws-lc-sys >= 0.42;
    # SPlayer's OpenSSL dependency cannot provide that library.
    splayer-next = prev.unstable.splayer-next.overrideAttrs (old: {
      buildInputs = old.buildInputs ++ [ prev.unstable.aws-lc ];
    });
  };

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
