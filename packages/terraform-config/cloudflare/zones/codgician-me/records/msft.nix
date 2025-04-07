{ config, ... }:
let
  ttl = 3600;
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
in
{
  resource.cloudflare_dns_record = {
    autodiscover-cname = {
      name = "autodiscover.${zone_name}";
      proxied = false;
      comment = "Microsoft Exchange Auto-discovery";
      type = "CNAME";
      content = "autodiscover.outlook.com";
      inherit zone_id ttl;
    };

    enterpriseenrollment-cname = {
      name = "enterpriseenrollment.${zone_name}";
      proxied = false;
      comment = "Intune MDM";
      type = "CNAME";
      content = "enterpriseenrollment-s.manage.microsoft.com";
      inherit zone_id ttl;
    };

    enterpriseregistration-cname = {
      name = "enterpriseregistration.${zone_name}";
      proxied = false;
      comment = "Intune MDM";
      type = "CNAME";
      content = "enterpriseregistration.windows.net";
      inherit zone_id ttl;
    };

    exchange-txt = {
      name = zone_name;
      comment = "SFP TXT record for Microsoft Exchange";
      type = "TXT";
      content = "v=spf1 include:spf.protection.outlook.com -all";
      inherit zone_id ttl;
    };

    exchange-mx = {
      name = zone_name;
      comment = "MX record for Microsoft Exchange";
      type = "MX";
      content = "codgician-me.mail.protection.outlook.com";
      priority = 0;
      inherit zone_id ttl;
    };
  };
}
