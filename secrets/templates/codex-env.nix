{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.allHosts;
  content = ''
    OPENAI_API_KEY=${ref "codex-openai-api-key"}
  '';
}
