{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  owner = "codgi";
  content = ref "litellm-user-api-key";
}
