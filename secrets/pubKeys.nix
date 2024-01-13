rec {
  # Keys
  hosts = {
    mona = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICNKqYpI7+zPOT72qvydVAdzsBNb0KiLbKFXHL9Ll0/Y" ];
    noir = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO41hU7TrSDOYm5BC1fXUz6CMwjjaywvkbZhAfH1hpsD" ];
    Shijia-Mac = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOS+hXPeUC7xFR74y5PCT0Ba0AXSC5vJJA5UURThXySJ" ];
    violet = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTdhkIHxijiGSGZtu0whn6DsU1uut+iiIfpEINxRzSW" ];
    wsl = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGY2tv025GT+GplUgx1oeuxv9o1EAke1HMSssRX19EF0" ];
  };

  users = {
    codgi = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/Mohin9ceHn6zpaRYWi3LeATeXI7ydiMrP3RsglZ2r" ];
  };

  # Aliases
  someHosts = xs: (builtins.concatMap (x: builtins.getAttr x hosts) xs) ++ users.codgi;
  allServers = builtins.concatLists [ hosts.mona hosts.violet users.codgi ];
  allHosts = (builtins.concatLists (builtins.attrValues hosts)) ++ users.codgi;
  everyone = builtins.concatLists (builtins.concatMap builtins.attrValues [ hosts users ]);
}
