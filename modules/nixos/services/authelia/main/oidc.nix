{ config, ... }:
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
  ];
}
