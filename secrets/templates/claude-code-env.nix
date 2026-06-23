{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  content = ''
    ANTHROPIC_BASE_URL="https://dendro.codgician.me"
    ANTHROPIC_AUTH_TOKEN=${ref "litellm-user-api-key"}
  '';
}
