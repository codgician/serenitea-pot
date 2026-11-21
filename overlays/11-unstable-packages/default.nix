{ lib, fromUnstable, ... }:

lib.composeManyExtensions [
  (final: prev: {
    # cargoSetupHook requires system AWS-LC for aws-lc-sys >= 0.42;
    # SPlayer's OpenSSL dependency cannot provide that library.
    splayer-next = prev.splayer-next.overrideAttrs (old: {
      buildInputs = old.buildInputs ++ [ final.aws-lc ];
    });
  })

  (fromUnstable [
    "splayer-next"
    "prl-tools"
    "sing-box"
    "sing-geoip"
    "nexttrace"
    "zfs_unstable"
    "matrix-tuwunel"
    "looking-glass-client"
  ])
]
