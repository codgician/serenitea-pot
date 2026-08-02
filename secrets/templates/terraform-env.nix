{ ref, pubkeys, ... }:
{
  # Operator-scoped: Terraform secrets are consumed by `secrets run` on the
  # operator's machine, never decrypted on a host. `app = true` excludes this
  # from host sops.templates wiring; recipients of every raw secret it composes
  # are derived verbatim from this group.
  app = true;
  publicKeys = pubkeys.users.codgi;

  content = ''
    ARM_CLIENT_SECRET=${ref "arm-client-secret"}
    ARM_ACCESS_KEY=${ref "arm-access-key"}
    CLOUDFLARE_API_TOKEN=${ref "cloudflare-api-token"}
    CLOUDFLARE_EMAIL=${ref "cloudflare-email"}
    TF_VAR_binary_cache_cname=${ref "binary-cache-cname"}
  '';
}
