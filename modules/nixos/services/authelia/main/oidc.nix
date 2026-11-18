{ lib, ... }:
let
  url = service: "https://${lib.codgician.published.services.${service}.domain}";

  defaults = {
    public = false;
    authorization_policy = "two_factor";
    require_pkce = true;
    pkce_challenge_method = "S256";
    scopes = [
      "openid"
      "profile"
      "email"
      "groups"
    ];
    response_types = [ "code" ];
    grant_types = [ "authorization_code" ];
    access_token_signed_response_alg = "none";
    userinfo_signed_response_alg = "none";
    token_endpoint_auth_method = "client_secret_basic";
  };
in
{
  # OIDC clients
  # Docs: https://www.authelia.com/configuration/identity-providers/openid-connect/clients/
  clients = map (client: defaults // client) [
    {
      client_id = "jellyfin";
      client_name = "Jellyfin";
      # jellyfin-oidc-secret-authelia-main.age, hashed with pbkdf2
      client_secret = "$pbkdf2-sha512$310000$ftnChoRdVEHofX4YuOyTlw$JkG0pwOqqEjir.xeRSiH22diHGE.NVn7Q4vVB38jO0WtDAc4P5OSTrBVDMuLFh3Bx289px3xtXAREIZC2IKfrQ";
      redirect_uris = [ "${url "jellyfin"}/sso/OID/redirect/authelia-main" ];
      scopes = [
        "openid"
        "profile"
        "groups"
      ];
      token_endpoint_auth_method = "client_secret_post";
    }
    {
      client_id = "proxmox-ve";
      client_name = "Proxmox VE";
      # proxmox-ve-oidc-secret-authelia-main.age, hashed with pbkdf2
      client_secret = "$pbkdf2-sha512$310000$ukEvIApLnfEEmOko21MxRQ$cyEAkkrydzgW3ZZdQzbfwUtA9AMH.o3Y4VMiScKWtJ3JaSI3cXhaUueGyUrPIUNS1mrRuwCiAunnr0BxI.SIrw";
      redirect_uris = [ (url "simulanka") ];
    }
    {
      client_id = "akasha";
      client_name = "Akasha";
      # In open-webui-env.age, hashed with pbkdf2
      client_secret = "$pbkdf2-sha512$310000$ZKILB7Dr6u5JEH4qmpXa7g$blbLjgLx0tZXNlHguk3TPe3n1BGgPp6Q5agy/c71YAs7DHUu4ALaJSTTop7mbLU1/hCQpPjRr55LBaJYlcsalw";
      require_pkce = false;
      pkce_challenge_method = "";
      redirect_uris = [ "${url "open-webui"}/oauth/oidc/callback" ];
    }
    {
      client_id = "meshcentral";
      client_name = "MeshCentral";
      client_secret = "$pbkdf2-sha512$310000$3wBHZHE59oHLU7tiujMk5Q$/KSucx0AZIRORxV1TY3ewLiLzQiXrSVJc5cKtaYeHANSyoK3lKkVDnzDlvX2ETycwcxqJv758H48e/J/YXofAQ";
      redirect_uris = [ "${url "meshcentral"}/auth-oidc-callback" ];
      token_endpoint_auth_method = "client_secret_post";
    }
    {
      client_id = "home-assistant";
      client_name = "Home Assistant";
      client_secret = "$pbkdf2-sha512$310000$pT/gLgFD3bJ2/lWQBWROZA$c7N9VIP1OpKmmQsrnm8YmseHCA9BOaTcu0Wmlr890qyhTdsi1OC33yRHTgvS2zuAeH8B/lPuEnuot.vMpT2pAw";
      redirect_uris = [ "${url "hass"}/auth/oidc/callback" ];
      scopes = [
        "openid"
        "profile"
        "groups"
      ];
      token_endpoint_auth_method = "client_secret_post";
    }
    {
      client_id = "grafana";
      client_name = "Grafana";
      client_secret = "$pbkdf2-sha512$310000$.nzPvqkKqjtiIj6zYssbuA$aPu1J4WHwQzVu8QqEbXryJQovPuGZuICP2J5RXxLVZa31MoHYO/ECl2Vbl.3MO8pZmJcv8wSkpRz7ScM26xLmA";
      redirect_uris = [ "${url "grafana"}/login/generic_oauth" ];
    }
    {
      client_id = "gitlab";
      client_name = "GitLab";
      client_secret = "$pbkdf2-sha512$310000$.xucd49OxRoMf2eW3pyRMw$gpCOt/cv/EmYMtiu6Zk0h2OYdReXywjB7YXjYvnaW9zR4F8pj9bQxeZaJiNlVZlZjiH7BZww7JyG1hCleFgSHA";
      redirect_uris = [ "${url "gitlab"}/users/auth/openid_connect/callback" ];
    }
    {
      client_id = "dendro";
      client_name = "Dendro";
      client_secret = "$pbkdf2-sha512$310000$StrvFo16kdpf9nGt6Tdymg$dbwbqicvrLMWdDTNr9c0yGU5UyX7ql0w4tuIUMlhbr5rU7cr4jRxlWZtugGmvhjq8WMgcErYbVngTwqMWLNWjw";
      require_pkce = false;
      pkce_challenge_method = "";
      redirect_uris = [ "${url "litellm"}/sso/callback" ];
      access_token_signed_response_alg = "RS256";
    }
    {
      client_id = "matrix-tuwunel";
      client_name = "Matrix";
      client_secret = "$pbkdf2-sha512$310000$j/2TAny/IrIx0RAfLa049Q$JTikgW/VAT6323BVxgDh30ZPzHrlaAUoOJ4uaWPstI8DsKALlC5PbF5JMVAFu.Yhiq4A9B4rqQ9QZJHh3IHYuw";
      redirect_uris = [
        "${url "matrix-tuwunel"}/_matrix/client/unstable/login/sso/callback/matrix-tuwunel"
      ];
      scopes = [
        "openid"
        "offline_access"
        "profile"
        "email"
        "groups"
      ];
      response_modes = [ "form_post" ];
      grant_types = [
        "authorization_code"
        "refresh_token"
      ];
      token_endpoint_auth_method = "client_secret_post";
    }
  ];
}
