# Troubleshooting: Terraform Workflow

## Error: State drift (unexpected changes in plan)

**Cause**: Manual changes in cloud console

**Fix**:
```bash
nix run .#tfmgr -- shell
terraform refresh
exit
nix run .#tfmgr -- plan
```

---

## Error: Resource already exists

**Cause**: Resource created outside Terraform

**Fix**: Import into state:
```bash
nix run .#tfmgr -- shell
# Get resource ID from cloud console
terraform import cloudflare_dns_record.myrecord <zone_id>/<record_id>
exit
```

---

## Error: Authentication failed

**Causes**:
1. Credentials expired
2. Secret missing

**Check**:
1. Secret exists: `secrets/terraform-env.age`
2. Run `nix run .#chkexp` for expiry check
3. Rotate if needed: `agenix -e secrets/terraform-env.age`

---

## Error: "Invalid reference" in plan

**Cause**: Using Terraform interpolation instead of Nix attribute access

**Wrong**:
```nix
zone_id = "\${cloudflare_zone.codgician-me.id}";
```

**Correct**:
```nix
zone_id = config.resource.cloudflare_zone.codgician-me "id";
```

---

## Error: Resource replacement (-/+) unexpected

**Cause**: Changing an immutable attribute

**Action**:
1. Review if replacement is acceptable
2. If data loss risk, plan migration first
3. If okay, proceed with apply

---

## Error: "No such file" for .tf

**Cause**: Terranix didn't generate config

**Fix**: Check Nix syntax in terraform-config files:
```bash
nix eval .#packages.x86_64-linux.terraform-config
```

---

## DNS not resolving after apply

**Causes**:
1. DNS propagation delay (wait 5-10 min)
2. Wrong record type
3. Cloudflare proxy settings

**Check**:
```bash
# Direct query to Cloudflare
dig @1.1.1.1 myservice.codgician.me

# Check TTL
dig +nocmd +noall +answer myservice.codgician.me
```

---

## Can't destroy resource

**Cause**: Dependencies or protection

**Fix**:
```bash
nix run .#tfmgr -- shell
terraform state rm <resource>  # Remove from state only
# OR
terraform destroy -target=<resource>  # Actually destroy
```
