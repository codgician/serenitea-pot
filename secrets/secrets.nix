let
  pubKeys = import ../pubkeys.nix;
  hostKeys = [
    pubKeys.systems.mona
    pubKeys.systems.x1
  ];
in
{
  # User password
  "codgiPassword.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi ] ++ hostKeys);
  "codgiHashedPassword.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi ] ++ hostKeys);
  "bmcPassword.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi ] ++ hostKeys);
  "bmcHashedPassword.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi ] ++ hostKeys);

  # Cloudflare token
  "cloudflareCredential.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi pubKeys.systems.mona ]);

  # GitLab secrets
  "gitlabInitRootPasswd.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi pubKeys.systems.mona ]);
  "gitlabDb.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi pubKeys.systems.mona ]);
  "gitlabJws.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi pubKeys.systems.mona ]);
  "gitlabOtp.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi pubKeys.systems.mona ]);
  "gitlabSecret.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi pubKeys.systems.mona ]);
  "gitlabSmtp.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi pubKeys.systems.mona ]);

  # OmniAuth provider secrets
  "gitlabOmniAuthGitHub.age".publicKeys = builtins.concatLists ([ pubKeys.users.codgi pubKeys.systems.mona ]);
}
