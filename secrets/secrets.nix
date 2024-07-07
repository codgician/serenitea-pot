let
  pubKeys = import ./pubkeys.nix;
in
with pubKeys; with pubKeys.hosts; {
  # User password
  "codgiPassword.age".publicKeys = someHosts [ paimon ];
  "codgiHashedPassword.age".publicKeys = allHosts;
  "bmcPassword.age".publicKeys = someHosts [ paimon ];
  "bmcHashedPassword.age".publicKeys = someHosts [ paimon ];
  "kioskHashedPassword.age".publicKeys = someHosts [ charlotte ];

  # NUT password
  "nutPassword.age".publicKeys = someHosts [ fischl ];

  # Cloudflare token
  "cloudflareCredential.age".publicKeys = allServers;

  # GitLab secrets
  "gitlabInitRootPasswd.age".publicKeys = someHosts [ paimon ];
  "gitlabDb.age".publicKeys = someHosts [ paimon ];
  "gitlabJws.age".publicKeys = someHosts [ paimon ];
  "gitlabOtp.age".publicKeys = someHosts [ paimon ];
  "gitlabSecret.age".publicKeys = someHosts [ paimon ];
  "gitlabSmtp.age".publicKeys = someHosts [ paimon ];
  "gitlabOmniAuthGitHub.age".publicKeys = someHosts [ paimon ];

  # Matrix secrets
  "matrixGlobalPrivateKey.age".publicKeys = someHosts [ paimon ];
  "matrixEnv.age".publicKeys = someHosts [ paimon ];

  # Terraform secrets
  "terraformEnv.age".publicKeys = users.codgi;

  # WireGuard secrets
  "wgLuminePrivateKey.age".publicKeys = wgHosts;
  "wgSuzhouPrivateKey.age".publicKeys = wgHosts;
  "wgPresharedKey.age".publicKeys = wgHosts;
}
