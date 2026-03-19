{ ... }:

# OpenSSL 4.0 with ECH support and nginx built against it
#
# Provides:
#   - opensslUnstable: OpenSSL 4.0.0-alpha1 with ECH (RFC 9849)
#   - nginxMainlineEch: nginx mainline built with ECH-capable OpenSSL
#
# Usage in modules:
#   services.nginx.package = pkgs.nginxMainlineEch;
#
# WARNING: OpenSSL 4.0 is alpha software with breaking API changes.
# Only use nginxMainlineEch for services requiring ECH support.

final: prev:
let
  opensslUnstable = import ./openssl-unstable.nix { inherit prev; };
in
{
  inherit opensslUnstable;

  # nginx mainline with ECH support via OpenSSL 4.0
  # Includes patches for OpenSSL 4.0 compatibility:
  #   - Use ASN1_STRING accessor functions instead of direct struct access
  #   - Fix const-correctness for X509_NAME pointers
  nginxMainlineEch =
    (prev.nginxMainline.override { openssl = opensslUnstable; }).overrideAttrs
      (old: {
        patches = (old.patches or [ ]) ++ [
          ./patches/nginx-openssl-4.0-compat.patch
        ];
      });
}
