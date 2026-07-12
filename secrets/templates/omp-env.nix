{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  owner = "codgi";
  content = ''
    EXA_API_KEY=${ref "exa-api-key"}
  '';
}
