let
  pubkeys = import ./pubkeys.nix;

  mkRecipient = type: name: sshPublicKeys: {
    _type = type;
    inherit name sshPublicKeys;
  };
  hosts = builtins.mapAttrs (mkRecipient "sops-host") pubkeys.hosts;
  users = builtins.mapAttrs (mkRecipient "sops-user") pubkeys.users;

  rawSecrets = {
    amap-api-key = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    anubis-ed25519-private-key-hex = {
      hosts = with hosts; [ lumine ];
      users = with users; [ codgi ];
    };
    arm-access-key = {
      users = with users; [ codgi ];
      key = "ARM_ACCESS_KEY";
    };
    arm-client-secret = {
      users = with users; [ codgi ];
      key = "ARM_CLIENT_SECRET";
      expires = "2027-02-04";
    };
    authelia-main-jwks = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    authelia-main-jwt = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    authelia-main-session = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    authelia-main-storage = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    azure-akasha-api-key = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
    };
    binary-cache-cname = {
      users = with users; [ codgi ];
      key = "TF_VAR_binary_cache_cname";
    };
    claude-code-oauth-token = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
      expires = "2027-08-05";
    };
    cloudflare-api-token = {
      users = with users; [ codgi ];
      key = "CLOUDFLARE_API_TOKEN";
    };
    cloudflare-credential = {
      hosts = with hosts; [
        fischl
        lumine
        nahida
        paimon
        raiden-ei
        xianyun
      ];
      users = with users; [ codgi ];
    };
    cloudflare-email = {
      users = with users; [ codgi ];
      key = "CLOUDFLARE_EMAIL";
    };
    codex-openai-api-key = {
      hosts = with hosts; [
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
      users = with users; [ codgi ];
    };
    codgi-hashed-password = {
      hosts = with hosts; [
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
      users = with users; [ codgi ];
    };
    codgi-password = {
      hosts = with hosts; [
        jahoda
        paimon
      ];
      users = with users; [ codgi ];
    };
    context7-api-key = {
      hosts = with hosts; [
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
      users = with users; [ codgi ];
    };
    deepseek-api-key = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
    };
    docker-pat = {
      hosts = with hosts; [
        fischl
        lumine
        nahida
        paimon
        raiden-ei
        xianyun
      ];
      users = with users; [ codgi ];
    };
    exa-api-key = {
      hosts = with hosts; [
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
      users = with users; [ codgi ];
    };
    gcp-credentials = {
      users = with users; [ codgi ];
      key = "GOOGLE_CREDENTIALS";
    };
    gemini-api-key = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
    };
    github-access-token = {
      hosts = with hosts; [
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
      users = with users; [ codgi ];
      expires = "2026-10-15";
    };
    github-auth-header = {
      hosts = with hosts; [
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
      users = with users; [ codgi ];
    };
    gitlab-active-record-deterministic-key = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    gitlab-active-record-primary-key = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    gitlab-active-record-salt = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    gitlab-db = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    gitlab-init-root-password = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    gitlab-jws = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    gitlab-oidc-secret-authelia-main = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    gitlab-otp = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    gitlab-secret = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    google-maps-api-key = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    grafana-admin-password = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    grafana-oidc-secret-authelia-main = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    grafana-secret-key = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    jellyfin-oidc-secret-authelia-main = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    kiosk-hashed-password = {
      users = with users; [ codgi ];
    };
    litellm-akasha-api-key = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    litellm-master-key = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
    };
    litellm-oidc-client-secret = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
    };
    litellm-proxy-admin-id = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
    };
    litellm-ui-password = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
    };
    litellm-user-api-key = {
      hosts = with hosts; [
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
      users = with users; [ codgi ];
    };
    meshcentral-oidc-secret-authelia-main = {
      hosts = with hosts; [ fischl ];
      users = with users; [ codgi ];
    };
    nut-password = {
      hosts = with hosts; [
        fischl
        paimon
      ];
      users = with users; [ codgi ];
    };
    nvidia-nim-api-key = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
    };
    open-terminal-api-key = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    open-webui-oauth-client-secret = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    open-webui-secret-key = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    proxmox-ve-oidc-secret-authelia-main = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    sasl-xoauth2 = {
      hosts = with hosts; [
        fischl
        lumine
        nahida
        paimon
        raiden-ei
        xianyun
      ];
      users = with users; [ codgi ];
      expires = "2027-08-10";
    };
    saw-basic-auth = {
      hosts = with hosts; [ lumine ];
      users = with users; [ codgi ];
    };
    sing-codgi-proxy-password = {
      hosts = with hosts; [
        jahoda
        lumine
        xianyun
      ];
      users = with users; [ codgi ];
    };
    sing-ech-keys = {
      hosts = with hosts; [
        lumine
        xianyun
      ];
      users = with users; [ codgi ];
    };
    sing-itscd-proxy-password = {
      hosts = with hosts; [
        lumine
        xianyun
      ];
      users = with users; [ codgi ];
    };
    sing-lxm75-proxy-password = {
      hosts = with hosts; [
        lumine
        xianyun
      ];
      users = with users; [ codgi ];
    };
    sing-ss-lumidouce-password = {
      hosts = with hosts; [ jahoda ];
      users = with users; [ codgi ];
    };
    smb-hashed-password = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    smb-password = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    smb-qiaoying-hashed-password = {
      hosts = with hosts; [ zibai ];
      users = with users; [ codgi ];
    };
    smb-qiaoying-password = {
      hosts = with hosts; [ zibai ];
      users = with users; [ codgi ];
    };
    tencent-dns-credential = {
      hosts = with hosts; [ xianyun ];
      users = with users; [ codgi ];
    };
    tuwunel-oidc-secret-authelia-main = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    tuwunel-turn-secret = {
      hosts = with hosts; [ paimon ];
      users = with users; [ codgi ];
    };
    upsmon-password = {
      hosts = with hosts; [
        fischl
        paimon
      ];
      users = with users; [ codgi ];
    };
    vllm-api-key = {
      hosts = with hosts; [
        furina
        lumine
        paimon
        wanderer
      ];
      users = with users; [ codgi ];
    };
    wg-preshared-key-furina-lumine = {
      hosts = with hosts; [
        furina
        lumine
      ];
      users = with users; [ codgi ];
    };
    wg-preshared-key-furina-xianyun = {
      hosts = with hosts; [
        furina
        xianyun
      ];
      users = with users; [ codgi ];
    };
    wg-preshared-key-lumidouce-lumine = {
      hosts = with hosts; [ lumine ];
      users = with users; [ codgi ];
    };
    wg-preshared-key-lumidouce-xianyun = {
      hosts = with hosts; [ xianyun ];
      users = with users; [ codgi ];
    };
    wg-preshared-key-lumine-qiaoying = {
      hosts = with hosts; [ lumine ];
      users = with users; [ codgi ];
    };
    wg-preshared-key-lumine-xianyun = {
      hosts = with hosts; [
        lumine
        xianyun
      ];
      users = with users; [ codgi ];
    };
    wg-preshared-key-qiaoying-xianyun = {
      hosts = with hosts; [ xianyun ];
      users = with users; [ codgi ];
    };
    wg-private-key-furina = {
      hosts = with hosts; [ furina ];
      users = with users; [ codgi ];
    };
    wg-private-key-lumidouce = {
      users = with users; [ codgi ];
    };
    wg-private-key-lumine = {
      hosts = with hosts; [ lumine ];
      users = with users; [ codgi ];
    };
    wg-private-key-qiaoying = {
      users = with users; [ codgi ];
    };
    wg-private-key-xianyun = {
      hosts = with hosts; [ xianyun ];
      users = with users; [ codgi ];
    };
    wireless-codgi-pass = {
      hosts = with hosts; [ zibai ];
      users = with users; [ codgi ];
    };
    wireless-grassland-pass = {
      hosts = with hosts; [ zibai ];
      users = with users; [ codgi ];
    };
  };

  normalize =
    name: secret:
    let
      secretHosts = secret.hosts or [ ];
      secretUsers = secret.users or [ ];
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
