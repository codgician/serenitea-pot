{ ... }:

# nginx mainline built against OpenSSL 4.0 for ECH (RFC 9849) support
#
# Provides:
#   - nginxMainlineEch: nginx mainline built with ECH-capable OpenSSL 4.0
#
# Usage in modules:
#   services.nginx.package = pkgs.nginxMainlineEch;
#
# WARNING: OpenSSL 4.0 has breaking API changes vs 3.x. Only use
# nginxMainlineEch for services requiring ECH support.

final: prev: {
  # nginx mainline with ECH support via OpenSSL 4.0
  # Includes a patch for OpenSSL 4.0 API compatibility:
  #   - Use ASN1_STRING accessor functions instead of direct struct access
  #   - Fix const-correctness for X509_NAME / ASN1_INTEGER pointers
  # The patch is still required as of nginx 1.29.x (upstream has not
  # adopted const accessors yet). Re-check on nginx upgrades.
  nginxMainlineEch =
    (prev.nginxMainline.override { openssl = prev.openssl_4_0; }).overrideAttrs
      (old: {
        patches = (old.patches or [ ]) ++ [
          ./patches/nginx-openssl-4.0-compat.patch
        ];
      });
}
