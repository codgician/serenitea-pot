{ pkgs, ... }:

{
  terraform = {
    required_providers.cloudflare = {
      source = "cloudflare/cloudflare";
      version = pkgs.unstable.terraform-providers.cloudflare_cloudflare.version;
    };
  };

  provider.cloudflare = {
    # Cloudflare API token provided via CLOUDFLARE_API_TOKEN
  };
}
