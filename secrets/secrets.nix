let
  pubKeys = import ./pubkeys.nix;
in
with pubKeys;
with pubKeys.hosts;
{
  # Authelia
  "authelia-main-jwt.age".publicKeys = someHosts [ paimon ];
  "authelia-main-session.age".publicKeys = someHosts [ paimon ];
  "authelia-main-storage.age".publicKeys = someHosts [ paimon ];
  "authelia-main-jwks.age".publicKeys = someHosts [ paimon ];

  # Docker
  "docker-pat.age".publicKeys = allServers;

  # Sasl XOAuth2 config
  "sasl-xoauth2.age" = {
    publicKeys = allServers;
    expiryDates = [ "2027-08-10" ];
  };

  # OIDC secrets
  "grafana-oidc-secret-authelia-main.age".publicKeys = someHosts [ paimon ];
  "jellyfin-oidc-secret-authelia-main.age".publicKeys = someHosts [ paimon ];
  "meshcentral-oidc-secret-authelia-main.age".publicKeys = someHosts [ fischl ];
  "proxmox-ve-oidc-secret-authelia-main.age".publicKeys = someHosts [ paimon ];

  # Wireless credentials
  "wireless-env.age".publicKeys = someHosts [ ];

  # User password
  "codgi-password.age".publicKeys = someHosts [ paimon ];
  "codgi-hashed-password.age".publicKeys = allHosts;
  "smb-password.age".publicKeys = someHosts [ paimon ];
  "smb-hashed-password.age".publicKeys = someHosts [ paimon ];
  "kiosk-hashed-password.age".publicKeys = someHosts [ ];

  # NUT password
  "nut-password.age".publicKeys = someHosts [
    fischl
    paimon
  ];
  "upsmon-password.age".publicKeys = someHosts [
    fischl
    paimon
  ];

  # Cloudflare token
  "cloudflare-credential.age".publicKeys = allServers;

  # Nix access tokens
  "nix-access-tokens.age" = {
    publicKeys = allHosts;
    expiryDates = [ "2026-11-09" ];
  };

  # GitLab secrets
  "gitlab-init-root-password.age".publicKeys = someHosts [ paimon ];
  "gitlab-db.age".publicKeys = someHosts [ paimon ];
  "gitlab-jws.age".publicKeys = someHosts [ paimon ];
  "gitlab-otp.age".publicKeys = someHosts [ paimon ];
  "gitlab-secret.age".publicKeys = someHosts [ paimon ];
  "gitlab-active-record-salt.age".publicKeys = someHosts [ paimon ];
  "gitlab-active-record-primary-key.age".publicKeys = someHosts [ paimon ];
  "gitlab-active-record-deterministic-key.age".publicKeys = someHosts [ paimon ];
  "gitlab-oidc-secret-authelia-main.age".publicKeys = someHosts [ paimon ];

  # Grafana secrets
  "grafana-admin-password.age".publicKeys = someHosts [ paimon ];
  "grafana-secret-key.age".publicKeys = someHosts [ paimon ];

  # Matrix secrets
  "matrix-global-private-key.age".publicKeys = someHosts [ paimon ];
  "matrix-env.age".publicKeys = someHosts [ paimon ];

  # mcp secrets
  "mcp-amap-api-key.age".publicKeys = someHosts [ paimon ];
  "mcp-google-maps-api-key.age".publicKeys = someHosts [ paimon ];

  # Open-WebUI secrets
  "open-webui-env.age".publicKeys = someHosts [ paimon ];

  # LiteLLM secrets
  "litellm-env.age".publicKeys = someHosts [
    furina
    lumine
    paimon
    wanderer
  ];

  # Sing secrets
  "sing-ech-keys.age".publicKeys = publicServers;
  "sing-codgi-proxy-password.age".publicKeys = publicServers;
  "sing-lxm75-proxy-password.age".publicKeys = publicServers;
  "sing-itscd-proxy-password.age".publicKeys = publicServers;

  # Terraform secrets
  "terraform-env.age" = {
    publicKeys = users.codgi;
    expiryDates = [
      "2027-02-04" # ARM_CLIENT_SECRET: caribert
    ];
  };

  # WireGuard private keys
  "wg-private-key-furina.age".publicKeys = someHosts [ furina ];
  "wg-private-key-lumine.age".publicKeys = someHosts [ lumine ];
  "wg-private-key-lumidouce.age".publicKeys = someHosts [ ];
  "wg-private-key-qiaoying.age".publicKeys = someHosts [ ];
  "wg-private-key-xianyun.age".publicKeys = someHosts [ xianyun ];

  # WireGuard preshared keys
  "wg-preshared-key-furina-lumine.age".publicKeys = someHosts [
    furina
    lumine
  ];
  "wg-preshared-key-furina-xianyun.age".publicKeys = someHosts [
    furina
    xianyun
  ];
  "wg-preshared-key-lumidouce-lumine.age".publicKeys = someHosts [ lumine ];
  "wg-preshared-key-lumidouce-xianyun.age".publicKeys = someHosts [ xianyun ];
  "wg-preshared-key-lumine-qiaoying.age".publicKeys = someHosts [ lumine ];
  "wg-preshared-key-lumine-xianyun.age".publicKeys = someHosts [
    lumine
    xianyun
  ];
  "wg-preshared-key-qiaoying-xianyun.age".publicKeys = someHosts [ xianyun ];
}
