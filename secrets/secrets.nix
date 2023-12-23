let
  pubKeys = import ../pubkeys.nix;
  servers = [
    pubKeys.systems.mona
    pubKeys.systems.violet
  ];
  all = servers ++ [ pubKeys.users.codgi ];
in
{
  # User password
  "codgiPassword.age".publicKeys = builtins.concatLists all;
  "codgiHashedPassword.age".publicKeys = builtins.concatLists all;
  "bmcPassword.age".publicKeys = builtins.concatLists all;
  "bmcHashedPassword.age".publicKeys = builtins.concatLists all;

  # Cloudflare token
  "cloudflareCredential.age".publicKeys = builtins.concatLists all;

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