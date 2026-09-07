{ ref }:
{
  owner = "codgi";
  content = ''
    OPENAI_API_KEY=${ref "litellm-user-api-key"}
  '';
}
