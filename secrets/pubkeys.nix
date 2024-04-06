rec {
  # Keys
  hosts = {
    charlotte = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILL9hl37txex438IfgZQ57uyLgf/WwDxypk9JoUT2Mya" ];
    focalors = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9elJzxtHicXWL+okluqOjCJ/ZcMlAuPqH/WyTnjfeW" ];
    furina = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOS+hXPeUC7xFR74y5PCT0Ba0AXSC5vJJA5UURThXySJ" ];
    lumine = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjCvIx+0G36EFWdw8nbrfqhkaCaDVsUJDiWnwfWtuEE" ];
    nahida = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTdhkIHxijiGSGZtu0whn6DsU1uut+iiIfpEINxRzSW" ];
    paimon = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICNKqYpI7+zPOT72qvydVAdzsBNb0KiLbKFXHL9Ll0/Y" ];
    raiden-ei = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIB0g+aVDhTxpSHq7XnLLZvK2Lm9nxLdBNggzyqrD2Hf" ];
    wsl = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGY2tv025GT+GplUgx1oeuxv9o1EAke1HMSssRX19EF0" ];
  };

  users = {
    codgi = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/Mohin9ceHn6zpaRYWi3LeATeXI7ydiMrP3RsglZ2r" ];
  };

  # Aliases
  someHosts = xs: (builtins.concatLists xs) ++ users.codgi;
  allServers = builtins.concatLists (with hosts; with users; [ paimon nahida lumine codgi ]);
  allHosts = (builtins.concatLists (builtins.attrValues hosts)) ++ users.codgi;
  everyone = builtins.concatLists (builtins.concatMap builtins.attrValues [ hosts users ]);
}
