{ ref }:
{
  content = ''
    VLLM_API_KEY=${ref "vllm-api-key"}
  '';
}
