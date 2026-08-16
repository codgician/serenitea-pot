{ ref }:
{
  owner = "anubis";
  content = ''
    ED25519_PRIVATE_KEY_HEX=${ref "anubis-ed25519-private-key-hex"}
  '';
}
