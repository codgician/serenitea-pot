{ ... }:

# nginx mainline built against OpenSSL 4.0 for ECH (RFC 9849) support.
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
  nginxMainlineEch = prev.nginxMainline.override { openssl = prev.openssl_4_0; };
}
