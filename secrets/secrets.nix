{ pubkeys }: # pubkeys = import ./pubkeys.nix
let
  inherit (pubkeys)
    someHosts
    allHosts
    allServers
    publicServers
    hosts
    ;
in
{
  inherit pubkeys;

  # Every entry is a raw `values/<name>` sops file. Recipients come from one of
  # two sources (see lib/sops.nix):
  #   - explicit `publicKeys` here  -> directly-consumed secrets (host reads the
  #     decrypted file verbatim via codgician.secrets.files.<name>.path), or
  #   - derived from referencing templates -> env-bundle components (the template
  #     that composes the value supplies the recipients).
  # A secret with neither is unencryptable and fails at eval. The operator key is
  # always present via the someHosts/allHosts/... aliases.
  secrets = {
    # --- Direct single-value secrets (explicit recipients = agenix parity) ---

    # Authelia (paimon)
    authelia-main-jwt.publicKeys = someHosts [ hosts.paimon ];
    authelia-main-session.publicKeys = someHosts [ hosts.paimon ];
    authelia-main-storage.publicKeys = someHosts [ hosts.paimon ];
    authelia-main-jwks.publicKeys = someHosts [ hosts.paimon ];

    # Docker
    docker-pat.publicKeys = allServers;

    # Sasl XOAuth2
    sasl-xoauth2 = {
      publicKeys = allServers;
      expiryDate = "2027-08-10";
    };

    # MCP servers
    context7-api-key.publicKeys = allHosts;
    github-auth-header.publicKeys = allHosts;
    amap-api-key.publicKeys = someHosts [ hosts.paimon ];
    google-maps-api-key.publicKeys = someHosts [ hosts.paimon ];

    # OIDC secrets
    grafana-oidc-secret-authelia-main.publicKeys = someHosts [ hosts.paimon ];
    jellyfin-oidc-secret-authelia-main.publicKeys = someHosts [ hosts.paimon ];
    meshcentral-oidc-secret-authelia-main.publicKeys = someHosts [ hosts.fischl ];
    proxmox-ve-oidc-secret-authelia-main.publicKeys = someHosts [ hosts.paimon ];

    # User passwords (neededForUsers consumers set the flag in their module)
    codgi-password.publicKeys = someHosts [
      hosts.jahoda
      hosts.paimon
    ];
    codgi-hashed-password.publicKeys = allHosts;
    smb-password.publicKeys = someHosts [ hosts.paimon ];
    smb-hashed-password.publicKeys = someHosts [ hosts.paimon ];
    smb-qiaoying-password.publicKeys = someHosts [ hosts.zibai ];
    smb-qiaoying-hashed-password.publicKeys = someHosts [ hosts.zibai ];
    # kiosk has no host recipient in agenix today (someHosts [ ]); operator only.
    kiosk-hashed-password.publicKeys = someHosts [ ];

    # NUT / UPS
    nut-password.publicKeys = someHosts [
      hosts.fischl
      hosts.paimon
    ];
    upsmon-password.publicKeys = someHosts [
      hosts.fischl
      hosts.paimon
    ];

    # Cloudflare (DNS-01) credential
    cloudflare-credential.publicKeys = allServers;

    # Tencent Cloud DNS
    tencent-dns-credential.publicKeys = someHosts [ hosts.xianyun ];

    # Nix access tokens
    nix-access-tokens = {
      publicKeys = allHosts;
      expiryDate = "2026-08-12";
    };

    # GitLab
    gitlab-init-root-password.publicKeys = someHosts [ hosts.paimon ];
    gitlab-db.publicKeys = someHosts [ hosts.paimon ];
    gitlab-jws.publicKeys = someHosts [ hosts.paimon ];
    gitlab-otp.publicKeys = someHosts [ hosts.paimon ];
    gitlab-secret.publicKeys = someHosts [ hosts.paimon ];
    gitlab-active-record-salt.publicKeys = someHosts [ hosts.paimon ];
    gitlab-active-record-primary-key.publicKeys = someHosts [ hosts.paimon ];
    gitlab-active-record-deterministic-key.publicKeys = someHosts [ hosts.paimon ];
    gitlab-oidc-secret-authelia-main.publicKeys = someHosts [ hosts.paimon ];

    # Grafana
    grafana-admin-password.publicKeys = someHosts [ hosts.paimon ];
    grafana-secret-key.publicKeys = someHosts [ hosts.paimon ];

    # Tuwunel (Matrix)
    tuwunel-oidc-secret-authelia-main.publicKeys = someHosts [ hosts.paimon ];
    tuwunel-turn-secret.publicKeys = someHosts [ hosts.paimon ];

    # Open-WebUI direct (open-terminal api key; the env bundle is a template)
    open-terminal-api-key.publicKeys = someHosts [ hosts.paimon ];

    # Sing-box
    sing-ech-keys.publicKeys = publicServers;
    sing-codgi-proxy-password.publicKeys = publicServers ++ hosts.jahoda;
    sing-lxm75-proxy-password.publicKeys = publicServers;
    sing-itscd-proxy-password.publicKeys = publicServers;

    # PiKVM basic auth (rendered behind nginx on lumine)
    saw-basic-auth.publicKeys = someHosts [ hosts.lumine ];

    # WireGuard private keys (per-host)
    wg-private-key-furina.publicKeys = someHosts [ hosts.furina ];
    wg-private-key-lumine.publicKeys = someHosts [ hosts.lumine ];
    wg-private-key-lumidouce.publicKeys = someHosts [ ];
    wg-private-key-qiaoying.publicKeys = someHosts [ ];
    wg-private-key-xianyun.publicKeys = someHosts [ hosts.xianyun ];

    # WireGuard preshared keys (per peer-pair)
    wg-preshared-key-furina-lumine.publicKeys = someHosts [
      hosts.furina
      hosts.lumine
    ];
    wg-preshared-key-furina-xianyun.publicKeys = someHosts [
      hosts.furina
      hosts.xianyun
    ];
    wg-preshared-key-lumidouce-lumine.publicKeys = someHosts [ hosts.lumine ];
    wg-preshared-key-lumidouce-xianyun.publicKeys = someHosts [ hosts.xianyun ];
    wg-preshared-key-lumine-qiaoying.publicKeys = someHosts [ hosts.lumine ];
    wg-preshared-key-lumine-xianyun.publicKeys = someHosts [
      hosts.lumine
      hosts.xianyun
    ];
    wg-preshared-key-qiaoying-xianyun.publicKeys = someHosts [ hosts.xianyun ];

    # --- Template-derived components (recipients from referencing templates) ---

    # terraform.env (app-scoped, operator only). GCP auth is NOT here: the GCP
    # service-account key lives solely in the gcp-credentials.json raw secret
    # (tfmgr decrypts it to a tmpfs file and points terraform at it through
    # GOOGLE_APPLICATION_CREDENTIALS), so the old terraform-env GOOGLE_CREDENTIALS
    # value is dropped as a duplicate.
    arm-client-secret.expiryDate = "2027-02-04"; # caribert service principal
    arm-access-key = { };
    cloudflare-api-token = { };
    cloudflare-email = { };

    # GCP service-account credential. Stored as a single fully-encrypted raw
    # value (the whole JSON is opaque ciphertext, so the service-account
    # identity in client_email/project_id is not exposed in git). The name omits
    # a `.json` extension to satisfy the [a-z0-9-]+ secret-name contract; the
    # content is what matters. tfmgr decrypts it to a tmpfs file and points
    # GOOGLE_APPLICATION_CREDENTIALS there. Operator-only: no host/template refs.
    gcp-credentials.publicKeys = pubkeys.users.codgi;

    # Shared env-bundle components (referenced by 2+ templates -> union recipients)
    vllm-api-key = { }; # litellm-env + vllm-env
    gemini-api-key = { }; # litellm-env + open-webui-env

    # litellm-env components
    litellm-master-key = { };
    litellm-oidc-client-secret = { };
    litellm-ui-password = { };
    azure-akasha-api-key = { };
    deepseek-api-key = { };
    nvidia-nim-api-key = { };
    anthropic-api-key = { };
    litellm-proxy-admin-id = { };

    # litellm api keys
    litellm-user-api-key = { };
    litellm-akasha-api-key = { };

    # open-webui-env components
    open-webui-secret-key = { };
    google-pse-engine-id = { };
    google-pse-api-key = { };
    open-webui-oauth-client-secret = { };

    # anubis-env component
    anubis-ed25519-private-key-hex = { };

    # codex-env component
    codex-openai-api-key = { };

    # wireless-env components
    wireless-codgi-pass = { };
    wireless-grassland-pass = { };
  };
}
