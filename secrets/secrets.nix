let
  pubKeys = import ./pubkeys.nix;
in
with pubKeys;
with pubKeys.hosts;
{
  # Wireless credentials
  "wireless-env.age".publicKeys = someHosts [ sigewinne ];

  # User password
  "codgi-password.age".publicKeys = someHosts [ yoimiya ];
  "codgi-hashed-password.age".publicKeys = allHosts;
  "smb-password.age".publicKeys = someHosts [ yoimiya ];
  "smb-hashed-password.age".publicKeys = someHosts [ yoimiya ];
  "kiosk-hashed-password.age".publicKeys = someHosts [ sigewinne ];

  # NUT password
  "nut-password.age".publicKeys = someHosts [
    fischl
    yoimiya
  ];
  "upsmon-password.age".publicKeys = someHosts [
    fischl
    yoimiya
  ];

  # Cloudflare token
  "cloudflare-credential.age".publicKeys = allServers;

  # Nix access tokens
  "nix-access-tokens.age" = {
    publicKeys = allHosts;
    expiryDates = [ "2025-12-07" ];
  };

  # GitLab secrets
  "gitlab-init-root-password.age".publicKeys = someHosts [
    paimon
    yoimiya
  ];
  "gitlab-db.age".publicKeys = someHosts [
    paimon
    yoimiya
  ];
  "gitlab-jws.age".publicKeys = someHosts [
    paimon
    yoimiya
  ];
  "gitlab-otp.age".publicKeys = someHosts [
    paimon
    yoimiya
  ];
  "gitlab-secret.age".publicKeys = someHosts [
    paimon
    yoimiya
  ];
  "gitlab-smtp.age".publicKeys = someHosts [
    paimon
    yoimiya
  ];
  "gitlab-omniauth-github.age".publicKeys = someHosts [
    paimon
    yoimiya
  ];

  # Grafana secrets
  "grafana-admin-password.age".publicKeys = someHosts [ lumine ];
  "grafana-secret-key.age".publicKeys = someHosts [ lumine ];
  "grafana-smtp.age".publicKeys = someHosts [ lumine ];

  # Matrix secrets
  "matrix-global-private-key.age".publicKeys = someHosts [
    paimon
    yoimiya
  ];
  "matrix-env.age".publicKeys = someHosts [
    paimon
    yoimiya
  ];

  # Open-WebUI secrets
  "open-webui-env.age".publicKeys = someHosts [ nahida ];

  # LiteLLM secrets
  "litellm-env.age".publicKeys = someHosts [ nahida ];

  # Terraform secrets
  "terraform-env.age" = {
    publicKeys = users.codgi;
    expiryDates = [
      "2027-02-04" # ARM_CLIENT_SECRET: caribert
    ];
  };

  # WireGuard private keys
  "wg-private-key-lumine.age".publicKeys = someHosts [ lumine ];
  "wg-private-key-lumidouce.age".publicKeys = someHosts [ ];
  "wg-private-key-qiaoying.age".publicKeys = someHosts [ ];
  "wg-private-key-xianyun.age".publicKeys = someHosts [ xianyun ];

  # WireGuard preshared keys
  "wg-preshared-key-lumidouce-lumine.age".publicKeys = someHosts [ lumine ];
  "wg-preshared-key-lumidouce-xianyun.age".publicKeys = someHosts [ xianyun ];
  "wg-preshared-key-lumine-qiaoying.age".publicKeys = someHosts [ lumine ];
  "wg-preshared-key-lumine-xianyun.age".publicKeys = someHosts [
    lumine
    xianyun
  ];
  "wg-preshared-key-qiaoying-xianyun.age".publicKeys = someHosts [ xianyun ];
}
