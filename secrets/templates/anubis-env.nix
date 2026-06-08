{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.someHosts [ pubkeys.hosts.lumine ];
  # Anubis reads this via EnvironmentFile; agenix owned it by the anubis user, so
  # the rendered file keeps that owner for parity.
  owner = "anubis";
  content = ''
    ED25519_PRIVATE_KEY_HEX=${ref "anubis-ed25519-private-key-hex"}
  '';
}
