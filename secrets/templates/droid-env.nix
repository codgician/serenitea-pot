{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  content = ''
    PROVIDER_API_KEY=${ref "anthropic-auth-token"}
  '';
}
