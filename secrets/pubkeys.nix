rec {
  # Keys
  hosts = {
    fischl = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDCFFJFcaGtTPeoI+A9MjZvyqIdrsZBIw7MOD4S7hQyJ" ];
    focalors = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9elJzxtHicXWL+okluqOjCJ/ZcMlAuPqH/WyTnjfeW" ];
    furina = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOS+hXPeUC7xFR74y5PCT0Ba0AXSC5vJJA5UURThXySJ" ];
    lumine = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICLgMH2GQZCfmXV2I4jlVHsM6PYiitT9hPRNhX40amKE" ];
    nahida = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTdhkIHxijiGSGZtu0whn6DsU1uut+iiIfpEINxRzSW" ];
    paimon = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICNKqYpI7+zPOT72qvydVAdzsBNb0KiLbKFXHL9Ll0/Y" ];
    raiden-ei = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIB0g+aVDhTxpSHq7XnLLZvK2Lm9nxLdBNggzyqrD2Hf" ];
    sigewinne = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILL9hl37txex438IfgZQ57uyLgf/WwDxypk9JoUT2Mya" ];
    wanderer = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPip23VXc7cxTRexddjDPpi90cBvQoxjNGPqSCVG1fvr" ];
    xianyun = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmOBQu1zv4bsSMw7uVvYkFhGz+jOUXwgJLOe8wAVz0P" ];
  };

  users = {
    codgi = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/Mohin9ceHn6zpaRYWi3LeATeXI7ydiMrP3RsglZ2r" ];
  };

  # Aliases
  someHosts = xs: (builtins.concatLists xs) ++ users.codgi;
  allServers = builtins.concatLists (
    with hosts;
    with users;
    [
      paimon
      nahida
      lumine
      raiden-ei
      fischl
      codgi
    ]
  );
  allHosts = (builtins.concatLists (builtins.attrValues hosts)) ++ users.codgi;
  everyone = builtins.concatLists (
    builtins.concatMap builtins.attrValues [
      hosts
      users
    ]
  );
}
