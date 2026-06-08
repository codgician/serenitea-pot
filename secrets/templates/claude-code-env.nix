{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  content = ''
    ANTHROPIC_BASE_URL=${ref "claude-code-anthropic-base-url"}
    ANTHROPIC_AUTH_TOKEN=${ref "anthropic-auth-token"}
  '';
}
