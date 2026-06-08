{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.someHosts [ pubkeys.hosts.paimon ];
  content = ''
    VLLM_API_KEY=${ref "vllm-api-key"}
  '';
}
