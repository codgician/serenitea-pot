let
  pubkeys = import ./pubkeys.nix;

  mkRecipient = type: name: sshPublicKeys: {
    _type = type;
    inherit name sshPublicKeys;
  };
  hosts = builtins.mapAttrs (mkRecipient "sops-host") pubkeys.hosts;
  users = builtins.mapAttrs (mkRecipient "sops-user") pubkeys.users;

  # Every secret is also encrypted to `users.codgi` unless it sets `users`.
  rawSecrets = with hosts; {
    amap-api-key.hosts = [ paimon ];
    anthropic-api-key.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
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
    azure-akasha-api-key.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
    binary-cache-cname.key = "TF_VAR_binary_cache_cname";
    claude-code-oauth-token = {
      hosts = [
        furina
        lumine
        paimon
        wanderer
      ];
      expires = "2027-08-05";
    };
    cloudflare-api-token.key = "CLOUDFLARE_API_TOKEN";
    cloudflare-credential.hosts = [
      fischl
      lumine
      nahida
      paimon
      xianyun
    ];
    codex-openai-api-key.hosts = [
      fischl
      focalors
      furina
      jahoda
      lumine
      nahida
      odette
      paimon
      sandrone
      wanderer
      xianyun
      zibai
    ];
    codgi-hashed-password.hosts = [
      fischl
      focalors
      furina
      jahoda
      lumine
      nahida
      odette
      paimon
      sandrone
      wanderer
      xianyun
      zibai
    ];
    codgi-password.hosts = [
      jahoda
      paimon
    ];
    context7-api-key.hosts = [
      fischl
      focalors
      furina
      jahoda
      lumine
      nahida
      odette
      paimon
      sandrone
      wanderer
      xianyun
      zibai
    ];
    coturn-auth-secret.hosts = [
      paimon
      xianyun
    ];
    deepseek-api-key.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
    docker-pat.hosts = [
      fischl
      lumine
      nahida
      paimon
      xianyun
    ];
    exa-api-key.hosts = [
      fischl
      focalors
      furina
      jahoda
      lumine
      nahida
      odette
      paimon
      sandrone
      wanderer
      xianyun
      zibai
    ];
    gcp-credentials.key = "GOOGLE_CREDENTIALS";
    gemini-api-key.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
    github-access-token = {
      hosts = [
        fischl
        focalors
        furina
        jahoda
        lumine
        nahida
        odette
        paimon
        sandrone
        wanderer
        xianyun
        zibai
      ];
      expires = "2026-12-25";
    };
    github-auth-header.hosts = [
      fischl
      focalors
      furina
      jahoda
      lumine
      nahida
      odette
      paimon
      sandrone
      wanderer
      xianyun
      zibai
    ];
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
    litellm-master-key.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
    litellm-oidc-client-secret.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
    litellm-proxy-admin-id.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
    litellm-ui-password.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
    litellm-user-api-key.hosts = [
      fischl
      focalors
      furina
      jahoda
      lumine
      nahida
      odette
      paimon
      sandrone
      wanderer
      xianyun
      zibai
    ];
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
    nvidia-nim-api-key.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
    open-terminal-api-key.hosts = [ paimon ];
    open-webui-oauth-client-secret.hosts = [ paimon ];
    open-webui-secret-key.hosts = [ paimon ];
    proxmox-ve-oidc-secret-authelia-main.hosts = [ paimon ];
    sasl-xoauth2 = {
      hosts = [
        fischl
        lumine
        nahida
        paimon
        xianyun
      ];
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
    vllm-api-key.hosts = [
      furina
      lumine
      paimon
      wanderer
    ];
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
