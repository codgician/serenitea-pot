{ ... }:

final: prev: {
  # Fix direnv build on Darwin: GNUmakefile uses -linkmode=external which requires CGO
  # Refer: https://github.com/NixOS/nixpkgs/issues/502464
  direnv = prev.direnv.overrideAttrs (oldAttrs: {
    env = (oldAttrs.env or { }) // {
      CGO_ENABLED = if final.stdenv.hostPlatform.isDarwin then "1" else "0";
    };
  });
}
