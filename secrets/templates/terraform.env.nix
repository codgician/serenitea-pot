{ ref, pubkeys, ... }:
{
  # Operator-scoped: terraform secrets are consumed by the `tfmgr` app on the
  # operator's machine (app-side activation via `secrets render`), never
  # decrypted on a host. `app = true` excludes this from host sops.templates
  # wiring; the recipients of every raw secret it composes are derived verbatim
  # from this group.
  app = true;
  publicKeys = pubkeys.users.codgi;

  content = ''
    ARM_CLIENT_SECRET=${ref "arm-client-secret"}
    ARM_ACCESS_KEY=${ref "arm-access-key"}
    CLOUDFLARE_API_TOKEN=${ref "cloudflare-api-token"}
    CLOUDFLARE_EMAIL=${ref "cloudflare-email"}
  '';
}
