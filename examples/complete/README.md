# Complete Landing Zone

All modules enabled: nested departments, guardrails, baselines, identities
and central audit logging.

## Prerequisite

Central audit logging requires a one-time manual step: log in to the log
archive account console (via the `OrganizationAdmin` login authorization)
and create a CAM role named `LandingZoneLogArchiveAccess` trusting the
management account UIN, with `QcloudCOSFullAccess`. See the root README
"Central Audit Logging" section. Remove the `central_logging` variables and
set `enable_central_logging = false` to skip it.

## Usage

```bash
terraform init
terraform plan
terraform apply
```
