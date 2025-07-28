{ ... }:
{
  # OIDC clients
  # Docs: https://www.authelia.com/configuration/identity-providers/openid-connect/clients/
  clients = [
    {
      client_id = "jellyfin";
      client_name = "Jellyfin";
      # jellyfin-oidc-secret-authelia-main.age, hashed with pbkdf2
      client_secret = "$pbkdf2-sha512$310000$ftnChoRdVEHofX4YuOyTlw$JkG0pwOqqEjir.xeRSiH22diHGE.NVn7Q4vVB38jO0WtDAc4P5OSTrBVDMuLFh3Bx289px3xtXAREIZC2IKfrQ";
      public = false;
      authorization_policy = "two_factor";
      require_pkce = true;
      pkce_challenge_method = "S256";
      redirect_uris = [
        "https://fin.codgician.me/sso/OID/redirect/authelia-main"
      ];
      scopes = [
        "openid"
        "profile"
        "groups"
      ];
      response_types = [ "code" ];
      grant_types = [ "authorization_code" ];
      access_token_signed_response_alg = "none";
      userinfo_signed_response_alg = "none";
      token_endpoint_auth_method = "client_secret_post";
    }
    {
      client_id = "proxmox-ve";
      client_name = "Proxmox VE";
      # proxmox-ve-oidc-secret-authelia-main.age, hashed with pbkdf2
      client_secret = "$pbkdf2-sha512$310000$ukEvIApLnfEEmOko21MxRQ$cyEAkkrydzgW3ZZdQzbfwUtA9AMH.o3Y4VMiScKWtJ3JaSI3cXhaUueGyUrPIUNS1mrRuwCiAunnr0BxI.SIrw";
      public = false;
      authorization_policy = "two_factor";
      require_pkce = true;
      pkce_challenge_method = "S256";
      redirect_uris = [
        "https://pve.codgician.me"
      ];
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
    }
    {
      client_id = "akasha";
      client_name = "Akasha";
      # In open-webui-env.age, hashed with pbkdf2
      client_secret = "$pbkdf2-sha512$310000$ZKILB7Dr6u5JEH4qmpXa7g$blbLjgLx0tZXNlHguk3TPe3n1BGgPp6Q5agy/c71YAs7DHUu4ALaJSTTop7mbLU1/hCQpPjRr55LBaJYlcsalw";
      public = false;
      authorization_policy = "two_factor";
      require_pkce = false;
      pkce_challenge_method = "";
      redirect_uris = [
        "https://akasha.codgician.me/oauth/oidc/callback"
      ];
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
    }
    {
      client_id = "meshcentral";
      client_name = "MeshCentral";
      client_secret = "$pbkdf2-sha512$310000$3wBHZHE59oHLU7tiujMk5Q$/KSucx0AZIRORxV1TY3ewLiLzQiXrSVJc5cKtaYeHANSyoK3lKkVDnzDlvX2ETycwcxqJv758H48e/J/YXofAQ";
      public = false;
      authorization_policy = "two_factor";
      require_pkce = true;
      pkce_challenge_method = "S256";
      redirect_uris = [
        "https://amt.codgician.me/auth-oidc-callback"
      ];
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
      token_endpoint_auth_method = "client_secret_post";
    }
    {
      client_id = "home-assistant";
      client_name = "Home Assistant";
      client_secret = "$pbkdf2-sha512$310000$pT/gLgFD3bJ2/lWQBWROZA$c7N9VIP1OpKmmQsrnm8YmseHCA9BOaTcu0Wmlr890qyhTdsi1OC33yRHTgvS2zuAeH8B/lPuEnuot.vMpT2pAw";
      public = false;
      authorization_policy = "two_factor";
      require_pkce = true;
      pkce_challenge_method = "S256";
      redirect_uris = [
        "https://hass.codgician.me/auth/oidc/callback"
      ];
      scopes = [
        "openid"
        "profile"
        "groups"
      ];
      response_types = [ "code" ];
      grant_types = [ "authorization_code" ];
      access_token_signed_response_alg = "none";
      userinfo_signed_response_alg = "none";
      token_endpoint_auth_method = "client_secret_post";
    }
    {
      client_id = "grafana";
      client_name = "Grafana";
      client_secret = "$pbkdf2-sha512$310000$.nzPvqkKqjtiIj6zYssbuA$aPu1J4WHwQzVu8QqEbXryJQovPuGZuICP2J5RXxLVZa31MoHYO/ECl2Vbl.3MO8pZmJcv8wSkpRz7ScM26xLmA";
      public = false;
      authorization_policy = "two_factor";
      require_pkce = true;
      pkce_challenge_method = "S256";
      redirect_uris = [
        "https://lumenstone.codgician.me/login/generic_oauth"
      ];
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
    }
  ];
}
