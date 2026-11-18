let
  pubkeys = import ./pubkeys.nix;

  mkRecipient = type: name: sshPublicKeys: {
    _type = type;
    inherit name sshPublicKeys;
  };
  hosts = builtins.mapAttrs (mkRecipient "sops-host") pubkeys.hosts;
  users = builtins.mapAttrs (mkRecipient "sops-user") pubkeys.users;

  allHosts = with hosts; [
    fischl
    focalors
    furina
    jahoda
    lumine
    nahida
    odette
    paimon
    raiden-ei
    sandrone
    wanderer
    xianyun
    zibai
  ];
  litellmHosts = with hosts; [
    furina
    lumine
    paimon
    wanderer
  ];
  serverHosts = with hosts; [
    fischl
    lumine
    nahida
    paimon
    raiden-ei
    xianyun
  ];

  # Every secret is also encrypted to `users.codgi` unless it sets `users`.
  rawSecrets = with hosts; {
    amap-api-key.hosts = [ paimon ];
    anthropic-api-key.hosts = litellmHosts;
    antigravity-oauth-client-id.hosts = litellmHosts;
    antigravity-oauth-client-secret.hosts = litellmHosts;
    anubis-ed25519-private-key-hex.hosts = [ lumine ];
    arm-access-key.key = "ARM_ACCESS_KEY";
    arm-client-secret = {
      key = "ARM_CLIENT_SECRET";
      expires = "2027-02-04";
    };
    authelia-main-jwks.hosts = [ paimon ];
    authelia-main-jwt.hosts = [ paimon ];
    authelia-main-session.hosts = [ paimon ];
    authelia-main-storage.hosts = [ paimon ];
    azure-akasha-api-key.hosts = litellmHosts;
    binary-cache-cname.key = "TF_VAR_binary_cache_cname";
    claude-code-oauth-token = {
      hosts = litellmHosts;
      expires = "2027-08-05";
    };
    cloudflare-api-token.key = "CLOUDFLARE_API_TOKEN";
    cloudflare-credential.hosts = serverHosts;
    codex-openai-api-key.hosts = allHosts;
    codgi-hashed-password.hosts = allHosts;
    codgi-password.hosts = [
      jahoda
      paimon
    ];
    context7-api-key.hosts = allHosts;
    coturn-auth-secret.hosts = [
      paimon
      xianyun
    ];
    deepseek-api-key.hosts = litellmHosts;
    docker-pat.hosts = serverHosts;
    exa-api-key.hosts = allHosts;
    gcp-credentials.key = "GOOGLE_CREDENTIALS";
    gemini-api-key.hosts = litellmHosts;
    github-access-token = {
      hosts = allHosts;
      expires = "2026-12-25";
    };
    github-auth-header.hosts = allHosts;
    gitlab-active-record-deterministic-key.hosts = [ paimon ];
    gitlab-active-record-primary-key.hosts = [ paimon ];
    gitlab-active-record-salt.hosts = [ paimon ];
    gitlab-db.hosts = [ paimon ];
    gitlab-init-root-password.hosts = [ paimon ];
    gitlab-jws.hosts = [ paimon ];
    gitlab-oidc-secret-authelia-main.hosts = [ paimon ];
    gitlab-otp.hosts = [ paimon ];
    gitlab-secret.hosts = [ paimon ];
    gns3-server-password.hosts = [ paimon ];
    google-maps-api-key.hosts = [ paimon ];
    grafana-admin-password.hosts = [ paimon ];
    grafana-oidc-secret-authelia-main.hosts = [ paimon ];
    grafana-secret-key.hosts = [ paimon ];
    jellyfin-oidc-secret-authelia-main.hosts = [ paimon ];
    kiosk-hashed-password = { };
    litellm-akasha-api-key.hosts = [ paimon ];
    litellm-master-key.hosts = litellmHosts;
    litellm-oidc-client-secret.hosts = litellmHosts;
    litellm-proxy-admin-id.hosts = litellmHosts;
    litellm-ui-password.hosts = litellmHosts;
    litellm-user-api-key.hosts = allHosts;
    mdatp-onboard.hosts = [
      jahoda
      odette
    ];
    meshcentral-oidc-secret-authelia-main.hosts = [ fischl ];
    nats-controller-seed.hosts = [
      jahoda
      odette
    ];
    nats-extension-seed = { };
    nut-password.hosts = [
      fischl
      paimon
    ];
    nvidia-nim-api-key.hosts = litellmHosts;
    open-terminal-api-key.hosts = [ paimon ];
    open-webui-oauth-client-secret.hosts = [ paimon ];
    open-webui-secret-key.hosts = [ paimon ];
    proxmox-ve-oidc-secret-authelia-main.hosts = [ paimon ];
    sasl-xoauth2 = {
      hosts = serverHosts;
      expires = "2027-08-10";
    };
    saw-basic-auth.hosts = [ lumine ];
    sing-codgi-password = {
      hosts = [
        jahoda
        lumine
        xianyun
      ];
      key = "sing-codgi-proxy-password";
    };
    sing-codgi-ss-password.hosts = [
      jahoda
      lumine
      xianyun
    ];
    sing-ech-keys.hosts = [
      lumine
      xianyun
    ];
    sing-itscd-password = {
      hosts = [
        lumine
        xianyun
      ];
      key = "sing-itscd-proxy-password";
    };
    sing-itscd-ss-password.hosts = [
      lumine
      xianyun
    ];
    sing-lxm75-password = {
      hosts = [
        lumine
        xianyun
      ];
      key = "sing-lxm75-proxy-password";
    };
    sing-lxm75-ss-password.hosts = [
      lumine
      xianyun
    ];
    sing-ss-lumidouce-password.hosts = [
      jahoda
      odette
    ];
    sing-ss-password.hosts = [
      jahoda
      lumine
      xianyun
    ];
    smb-hashed-password.hosts = [ paimon ];
    smb-password.hosts = [ paimon ];
    smb-qiaoying-hashed-password.hosts = [ zibai ];
    smb-qiaoying-password.hosts = [ zibai ];
    tencent-dns-credential.hosts = [ xianyun ];
    tuwunel-oidc-secret-authelia-main.hosts = [ paimon ];
    upsmon-password.hosts = [
      fischl
      paimon
    ];
    vllm-api-key.hosts = litellmHosts;
    wg-preshared-key-furina-lumine.hosts = [
      furina
      lumine
    ];
    wg-preshared-key-furina-xianyun.hosts = [
      furina
      xianyun
    ];
    wg-preshared-key-lumidouce-lumine.hosts = [ lumine ];
    wg-preshared-key-lumidouce-xianyun.hosts = [ xianyun ];
    wg-preshared-key-lumine-qiaoying.hosts = [ lumine ];
    wg-preshared-key-lumine-xianyun.hosts = [
      lumine
      xianyun
    ];
    wg-preshared-key-qiaoying-xianyun.hosts = [ xianyun ];
    wg-private-key-furina.hosts = [ furina ];
    wg-private-key-lumidouce = { };
    wg-private-key-lumine.hosts = [ lumine ];
    wg-private-key-qiaoying = { };
    wg-private-key-xianyun.hosts = [ xianyun ];
    wireless-codgi-pass.hosts = [ zibai ];
    wireless-grassland-pass.hosts = [ zibai ];
  };

  normalize =
    name: secret:
    let
      secretHosts = secret.hosts or [ ];
      secretUsers = secret.users or [ users.codgi ];
    in
    assert builtins.all (recipient: (recipient._type or null) == "sops-host") secretHosts;
    assert builtins.all (recipient: (recipient._type or null) == "sops-user") secretUsers;
    {
      hosts = secretHosts;
      users = secretUsers;
      key = secret.key or name;
      expires = secret.expires or null;
    };
in
{
  inherit hosts users;
  secrets = builtins.mapAttrs normalize rawSecrets;
}
