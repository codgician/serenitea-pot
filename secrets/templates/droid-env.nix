{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  content = ''
    PROVIDER_API_KEY=${ref "litellm-user-api-key"}
  '';
}
