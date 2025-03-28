let
  pubKeys = import ./pubkeys.nix;
in
with pubKeys;
with pubKeys.hosts;
{
  # Wireless credentials
  "wirelessEnv.age".publicKeys = someHosts [ sigewinne ];

  # User password
  "codgiPassword.age".publicKeys = someHosts [ paimon ];
  "codgiHashedPassword.age".publicKeys = allHosts;
  "smbPassword.age".publicKeys = someHosts [ paimon ];
  "smbHashedPassword.age".publicKeys = someHosts [ paimon ];
  "kioskHashedPassword.age".publicKeys = someHosts [ sigewinne ];

  # NUT password
  "nutPassword.age".publicKeys = someHosts [ fischl ];
  "upsmonPassword.age".publicKeys = someHosts [ fischl ];

  # Cloudflare token
  "cloudflareCredential.age".publicKeys = allServers;

  # Nix access tokens
  "nixAccessTokens.age" = {
    publicKeys = allHosts;
    expiryDates = [ "2025-12-07" ];
  };

  # GitLab secrets
  "gitlabInitRootPasswd.age".publicKeys = someHosts [ paimon ];
  "gitlabDb.age".publicKeys = someHosts [ paimon ];
  "gitlabJws.age".publicKeys = someHosts [ paimon ];
  "gitlabOtp.age".publicKeys = someHosts [ paimon ];
  "gitlabSecret.age".publicKeys = someHosts [ paimon ];
  "gitlabSmtp.age".publicKeys = someHosts [ paimon ];
  "gitlabOmniAuthGitHub.age".publicKeys = someHosts [ paimon ];

  # Grafana secrets
  "grafanaAdminPassword.age".publicKeys = someHosts [ lumine ];
  "grafanaSecretKey.age".publicKeys = someHosts [ lumine ];
  "grafanaSmtp.age".publicKeys = someHosts [ lumine ];

  # Matrix secrets
  "matrixGlobalPrivateKey.age".publicKeys = someHosts [ paimon ];
  "matrixEnv.age".publicKeys = someHosts [ paimon ];

  # Open-WebUI secrets
  "openWebuiEnv.age".publicKeys = someHosts [ nahida ];

  # LiteLLM secrets
  "litellmEnv.age".publicKeys = someHosts [ nahida ];

  # Terraform secrets
  "terraformEnv.age" = {
    publicKeys = users.codgi;
    expiryDates = [
      "2027-02-04" # ARM_CLIENT_SECRET: caribert
    ];
  };

  # WireGuard secrets
  "wgLuminePrivateKey.age".publicKeys = wgHosts;
  "wgLumidoucePrivateKey.age".publicKeys = wgHosts;
  "wgQiaoyingPrivateKey.age".publicKeys = wgHosts;
  "wgXianyunPrivateKey.age".publicKeys = wgHosts;
  "wgPresharedKey.age".publicKeys = wgHosts;
}
