let
  pubKeys = import ./pubKeys.nix;
in
{
  # User password
  "codgiPassword.age".publicKeys = pubKeys.allHosts;
  "codgiHashedPassword.age".publicKeys = pubKeys.allHosts;
  "bmcPassword.age".publicKeys = pubKeys.someHosts [ "mona" ];
  "bmcHashedPassword.age".publicKeys = pubKeys.someHosts [ "mona" ];

  # Cloudflare token
  "cloudflareCredential.age".publicKeys = pubKeys.allServers;

  # GitLab secrets
  "gitlabInitRootPasswd.age".publicKeys = pubKeys.someHosts [ "mona" ];
  "gitlabDb.age".publicKeys = pubKeys.someHosts [ "mona" ];
  "gitlabJws.age".publicKeys = pubKeys.someHosts [ "mona" ];
  "gitlabOtp.age".publicKeys = pubKeys.someHosts [ "mona" ];
  "gitlabSecret.age".publicKeys = pubKeys.someHosts [ "mona" ];
  "gitlabSmtp.age".publicKeys = pubKeys.someHosts [ "mona" ];

  # OmniAuth provider secrets
  "gitlabOmniAuthGitHub.age".publicKeys = pubKeys.someHosts [ "mona" ];

  # Matrix secrets
  "matrixGlobalPrivateKey.age".publicKeys = pubKeys.someHosts [ "mona" ];
  "matrixEnv.age".publicKeys = pubKeys.someHosts [ "mona" ];
}
