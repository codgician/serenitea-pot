{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  content = ''
    DENDRO_API_KEY=${ref "litellm-user-api-key"}
  '';
}
