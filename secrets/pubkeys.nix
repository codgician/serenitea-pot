rec {
  # Keys
  hosts = {
    fischl = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDCFFJFcaGtTPeoI+A9MjZvyqIdrsZBIw7MOD4S7hQyJ" ];
    focalors = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9elJzxtHicXWL+okluqOjCJ/ZcMlAuPqH/WyTnjfeW" ];
    furina = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOS+hXPeUC7xFR74y5PCT0Ba0AXSC5vJJA5UURThXySJ" ];
    lumine = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICLgMH2GQZCfmXV2I4jlVHsM6PYiitT9hPRNhX40amKE" ];
    nahida = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID+oF/2GvNR5Adz0y6RiNTg8UrcneQSEWualML5wAwer" ];
    paimon = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFljYcA+U1awv/K4xHx9pr8+WVH/YDAN73nPlEhE3zJr" ];
    raiden-ei = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIB0g+aVDhTxpSHq7XnLLZvK2Lm9nxLdBNggzyqrD2Hf" ];
    sandrone = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIviqrRjXSzpnF6Q6gRfLGWwYEq5FsDiTLlMwnlUDQmS" ];
    wanderer = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMgX6g1a0atq3ObPNQz1A+hUnYpNEs1iGrfGWlXvszPD" ];
    xianyun = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmOBQu1zv4bsSMw7uVvYkFhGz+jOUXwgJLOe8wAVz0P" ];
    zibai = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBz7WFyT4JCS8LkOnNhwBcaWuFnap1/x4VJFqBz4vXnP" ];
  };

  users = {
    codgi = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/Mohin9ceHn6zpaRYWi3LeATeXI7ydiMrP3RsglZ2r" ];
  };

  # Aliases
  someHosts = xs: (builtins.concatLists xs) ++ users.codgi;

  publicServers' =
    with hosts;
    builtins.concatLists [
      lumine
      xianyun
    ];
  privateServers' =
    with hosts;
    builtins.concatLists [
      fischl
      nahida
      paimon
      raiden-ei
    ];
  allServers' = publicServers' ++ privateServers';
  allHosts' = builtins.concatLists (builtins.attrValues hosts);

  publicServers = publicServers' ++ users.codgi;
  privateServers = privateServers' ++ users.codgi;
  allServers = allServers' ++ users.codgi;
  allHosts = allHosts' ++ users.codgi;

  everyone = builtins.concatLists (
    builtins.concatMap builtins.attrValues [
      hosts
      users
    ]
  );
}
