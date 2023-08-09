let
  pubKeys = import ../pubkeys.nix;
in
{
  # User password
  "codgiPassword.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.pilot ];

  # Cloudflare token
  "cloudflareCredential.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.pilot ];

  # GitLab secrets
  "gitlabInitRootPasswd.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.pilot ];
  "gitlabDb.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.pilot ];
  "gitlabJws.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.pilot ];
  "gitlabOtp.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.pilot ];
  "gitlabSecret.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.pilot ];
  "gitlabSmtp.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.pilot ];
}
