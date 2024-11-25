{ config, ... }:
let
  ttl = 3600;
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
in
{
  resource.cloudflare_record = {
    autodiscover-cname = {
      name = "autodiscover";
      proxied = false;
      comment = "Microsoft Exchange Auto-discovery";
      type = "CNAME";
      content = "autodiscover.outlook.com";
      inherit zone_id ttl;
    };

    enterpriseenrollment-cname = {
      name = "enterpriseenrollment";
      proxied = false;
      comment = "Intune MDM";
      type = "CNAME";
      content = "enterpriseenrollment-s.manage.microsoft.com";
      inherit zone_id ttl;
    };

    enterpriseregistration-cname = {
      name = "enterpriseregistration";
      proxied = false;
      comment = "Intune MDM";
      type = "CNAME";
      content = "enterpriseregistration.windows.net";
      inherit zone_id ttl;
    };

    exchange-txt = {
      name = "@";
      comment = "SFP TXT record for Microsoft Exchange";
      type = "TXT";
      content = "v=spf1 include:spf.protection.outlook.com -all";
      inherit zone_id ttl;
    };

    exchange-mx = {
      name = "@";
      comment = "MX record for Microsoft Exchange";
      type = "MX";
      content = "codgician-me.mail.protection.outlook.com";
      priority = 0;
      inherit zone_id ttl;
    };
  };
}
