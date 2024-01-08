rec {
  # Public keys
  pubKeys = rec {
    systems = {
      mona = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICNKqYpI7+zPOT72qvydVAdzsBNb0KiLbKFXHL9Ll0/Y" ];
      violet = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTdhkIHxijiGSGZtu0whn6DsU1uut+iiIfpEINxRzSW" ];
      wsl = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGY2tv025GT+GplUgx1oeuxv9o1EAke1HMSssRX19EF0" ];
    };

    users = {
      codgi = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/Mohin9ceHn6zpaRYWi3LeATeXI7ydiMrP3RsglZ2r" ];
    };

    servers = [ systems.mona systems.violet ];
    all = builtins.concatLists (builtins.concatMap builtins.attrValues [ systems users ]);
  };

  # User password
  "codgiPassword.age".publicKeys = builtins.concatLists pubKeys.all;
  "codgiHashedPassword.age".publicKeys = builtins.concatLists pubKeys.all;
  "bmcPassword.age".publicKeys = builtins.concatLists pubKeys.all;
  "bmcHashedPassword.age".publicKeys = builtins.concatLists pubKeys.all;

  # Cloudflare token
  "cloudflareCredential.age".publicKeys = builtins.concatLists pubKeys.all;

  # GitLab secrets
  "gitlabInitRootPasswd.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.mona ];
  "gitlabDb.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.mona ];
  "gitlabJws.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.mona ];
  "gitlabOtp.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.mona ];
  "gitlabSecret.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.mona ];
  "gitlabSmtp.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.mona ];

  # OmniAuth provider secrets
  "gitlabOmniAuthGitHub.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.mona ];

  # Matrix secrets
  "matrixGlobalPrivateKey.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.mona ];
  "matrixEnv.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.mona ];
}
