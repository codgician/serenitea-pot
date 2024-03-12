let
  pubKeys = import ./pubKeys.nix;
in
with pubKeys.hosts; {
  # User password
  "codgiPassword.age".publicKeys = pubKeys.someHosts [ paimon ];
  "codgiHashedPassword.age".publicKeys = pubKeys.allHosts;
  "bmcPassword.age".publicKeys = pubKeys.someHosts [ paimon ];
  "bmcHashedPassword.age".publicKeys = pubKeys.someHosts [ paimon ];

  # Cloudflare token
  "cloudflareCredential.age".publicKeys = pubKeys.allServers;

  # GitLab secrets
  "gitlabInitRootPasswd.age".publicKeys = pubKeys.someHosts [ paimon ];
  "gitlabDb.age".publicKeys = pubKeys.someHosts [ paimon ];
  "gitlabJws.age".publicKeys = pubKeys.someHosts [ paimon ];
  "gitlabOtp.age".publicKeys = pubKeys.someHosts [ paimon ];
  "gitlabSecret.age".publicKeys = pubKeys.someHosts [ paimon ];
  "gitlabSmtp.age".publicKeys = pubKeys.someHosts [ paimon ];
  "gitlabOmniAuthGitHub.age".publicKeys = pubKeys.someHosts [ paimon ];

  # Matrix secrets
  "matrixGlobalPrivateKey.age".publicKeys = pubKeys.someHosts [ paimon ];
  "matrixEnv.age".publicKeys = pubKeys.someHosts [ paimon ];
}
