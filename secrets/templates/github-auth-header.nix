{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  content = "Bearer ${ref "github-access-token"}";
}
