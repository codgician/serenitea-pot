{ ... }:

final: prev: {
  unstable = prev.unstable.extend (
    unstableFinal: unstablePrev: {
      # cargoSetupHook requires system AWS-LC for aws-lc-sys >= 0.42;
      # SPlayer's OpenSSL dependency cannot provide that library.
      splayer-next = unstablePrev.splayer-next.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ unstableFinal.aws-lc ];
      });
    }
  );

  inherit (prev.unstable)
    prl-tools
    sing-box
    matrix-tuwunel
    looking-glass-client
    ;
}
