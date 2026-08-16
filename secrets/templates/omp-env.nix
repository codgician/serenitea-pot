{ ref }:
{
  owner = "codgi";
  content = ''
    EXA_API_KEY=${ref "exa-api-key"}
  '';
}
