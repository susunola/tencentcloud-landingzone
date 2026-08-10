<p align="center">
  <b>English</b> &nbsp;|&nbsp;
  <a href="README.zh-CN.md">简体中文</a>
</p>

# tencentcloud-landingzone

Terraform implementation of Tencent Cloud Control Center Landing Zone best practices. Deploys multi-account cloud environment **organization, core accounts, finance, identities, guardrails, and account baselines** in a versionable, auditable, repeatable way.

## Architecture

```
                    ┌──────────────────────────────┐
                    │  Management Account (terraform)│
                    └──────────────┬───────────────┘
                                   │ Enable Organization
                    ┌──────────────▼───────────────┐
                    │  Organization Service         │
                    └──────────────┬───────────────┘
                                   │
        ┌──────────────┬───────────┴───────────┬──────────────┐
        │              │                       │              │
   ┌────▼────┐   ┌─────▼─────┐          ┌──────▼─────┐   ┌────▼─────┐
   │ Core     │   │ Business │          │ Sandbox    │   │ Guardrails│
   │ Accounts │   │ Division │          │ Division   │   │ (SCP)     │
   │ Security │   │ Apps     │          │ Dev/Test   │   │ Bound to  │
   │ Logging  │   │          │          │            │   │ divisions │
   │ Finance  │   │          │          │            │   │           │
   └────┬────┘   └─────┬─────┘          └──────┬─────┘   └──────────┘
        │              │                       │
        └──────┬───────┴───────────┬───────────┘
               │                   │
        ┌──────▼──────┐    ┌───────▼────────┐
        │ Identities   │    │ Account Factory │
        │ & Permissions│    │ Baselines       │
        │ Permission   │    │ Tags/VPC/       │
        │ Sets/Members │    │ Contacts        │
        │ Policies/    │    │ Batch apply     │
        │ Login Auth   │    │ to accounts     │
        └─────────────┘    └────────────────┘
```

## Configuration Mapping

Maps to the 8 Control Center Landing Zone configuration areas:

| Control Center Config | Implementation | Terraform Resource |
|---|---|---|
| Departments | `organization.tf` | `tencentcloud_organization_org_node` |
| Core Accounts | `organization.tf` | `tencentcloud_organization_org_member` |
| Account Creation & Invitation | `organization.tf` | `tencentcloud_organization_org_member` |
| Finance | `organization.tf` + `variables.tf` | `permission_ids`, `pay_uin` |
| Identities & Permissions | `identities.tf` | `org_identity` / `org_member_policy_attachment` / `org_member_auth_identity_attachment` |
| Guardrails | `guardrails.tf` | `org_manage_policy` + `org_manage_policy_target` |
| Baseline Management | `baselines.tf` | `controlcenter_account_factory_baseline_config` + `batch_apply_account_baselines` |
| Compliance Audit (Log Shipping) | See notes below | Configure CloudAudit / Config shipping in log account |

> Log shipping (CloudAudit / Config logs to COS) requires enabling services within the log account. This can be done via console or `tencentcloud_audit` resources. The log account created by this repo is ready to host these configurations.

## Files

| File | Description |
|---|---|
| `main.tf` | Provider config, enable organization service |
| `organization.tf` | Departments, core/business/sandbox accounts, finance |
| `identities.tf` | Identities (permission sets), policy attachments, login authorization |
| `guardrails.tf` | Service Control Policies (SCP) and bindings |
| `baselines.tf` | Account factory baseline configs and batch application |
| `variables.tf` / `outputs.tf` | Input variables and outputs |
| `terraform.tfvars.example` | Variable examples |
| `scripts/validate-config.py` | Config preflight: validates tfvars reference consistency before apply |
| `.github/workflows/terraform-ci.yml` | CI: fmt + validate + preflight + optional plan |

## Prerequisites

- Management account has completed **enterprise real-name verification** (Control Center only supports enterprise accounts)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.3 installed locally
- Configure Tencent Cloud API credentials (choose one):
  - Environment variables: `export TENCENTCLOUD_SECRET_ID=... TENCENTCLOUD_SECRET_KEY=...`
  - `terraform.tfvars`: copy `terraform.tfvars.example` and fill in
- Preflight script requires `python3` + `python-hcl2`: `pip install python-hcl2` (auto-installed in CI)

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars   # Customize as needed
terraform init
terraform plan                                 # Review changes
terraform apply
```

First `apply` will sequentially: enable organization → create departments → create core/business accounts → create identities and bind → enable SCP and bind → configure baselines and apply to all accounts.

## Default Account Structure

```
Root Management Account
├── Core Accounts
│   ├── Security Account     # Centralized security products
│   ├── Log Account          # Centralized audit log collection
│   └── Finance Account      # Finance reconciliation & cost analysis
├── Business Division
│   └── AppA-Production
└── Sandbox Division
    └── DevTest
```

Adjust structure by modifying `departments` / `core_accounts` / `business_accounts` in `variables.tf`.

## Extension & Trimming

Data-driven design with feature flags. **Modify `terraform.tfvars` only — no code changes needed.**

| Requirement | Approach |
|---|---|
| Disable a module | Set `enable_guardrails` / `enable_baselines` / `enable_login_permission` / `enable_auditor_policy` to `false` |
| Add/remove divisions or accounts | Modify `departments` / `core_accounts` / `business_accounts` |
| Add/remove SCP guardrails | Modify `guardrail_policies` map (includes `bound_to` binding targets) |
| Add/remove baseline items | Modify `baseline_config_items` list |
| Adjust finance permissions | Modify `member_permission_ids` / `pay_uin` |
| Add/remove identities | Copy/delete identity resource blocks and bindings in `identities.tf` |

Minimal example (organization + accounts only, no governance modules):

```hcl
enable_guardrails       = false
enable_baselines        = false
enable_login_permission = false
enable_auditor_policy   = false
```

## Phased Deployment

For first-time deployment, apply in dependency order to reduce blast radius and verify each stage:

| Stage | Content | Command |
|---|---|---|
| 1 Org & Accounts | Enable org, departments, core/business accounts | `terraform apply -target=tencentcloud_organization_instance.this -target=tencentcloud_organization_org_node.this -target=tencentcloud_organization_org_member.core -target=tencentcloud_organization_org_member.business` |
| 2 Identities & Guardrails | Identities, policy bindings, login auth, SCP | `terraform apply -target=tencentcloud_organization_org_identity.* -target=tencentcloud_organization_org_member_policy_attachment.* -target=tencentcloud_organization_org_member_auth_identity_attachment.* -target=tencentcloud_organization_org_manage_policy.*` |
| 3 Baselines | Account factory baselines + batch apply | `terraform apply -target=tencentcloud_controlcenter_account_factory_baseline_config.default -target=tencentcloud_batch_apply_account_baselines.all` |
| 4 Finalize | Full reconciliation | `terraform apply` |

> After each stage, run `terraform plan` to confirm no unexpected changes before proceeding. With many accounts, pilot 1-2 business accounts first with `-target` to validate baseline effects, then apply fully.

## Continuous Governance

- **CI Validation**: `.github/workflows/terraform-ci.yml` runs `fmt -check`, `validate`, and config preflight on every PR/push. Plan step auto-enables after configuring `TENCENTCLOUD_SECRET_ID` / `TENCENTCLOUD_SECRET_KEY` in repository Settings → Secrets (skips if not configured).
- **Drift Detection**: Landing Zone compliance may drift due to manual console operations (e.g., manually changing departments or binding policies). Run `terraform plan` periodically and compare with CI results; converge drift with `terraform apply`.
- **Preflight Script**: Run `python3 scripts/validate-config.py` before apply to quickly catch department reference, finance permission, binding target, and other configuration errors — avoiding mid-plan failures.

## Baseline Items

`baselines.tf` is driven by `var.baseline_config_items`. Defaults include two account factory baseline items (extensible):

- `TCC-AF_PRESET_TAG`: Preset tag baseline for uniform management tags across all accounts
- `TCC-AF_VPC_SUBNET`: VPC/subnet baseline creating default network per account

Query available baseline items and their configuration schema via console or:

```hcl
data "tencentcloud_controlcenter_account_factory_baseline_items" "all" {}
```

Other common baseline items: `TCC-AF_SHARE_IMAGE` (shared image), `ACS-BP_ACCOUNT_FACTORY_ACCOUNT_CONTACT` (account contact).

## Notes

- **SCP defines permission boundaries only, does not grant permissions**: Effective permissions = SCP ∩ CAM permissions within the account. CAM still needs to be configured inside each member account.
- **After SCP is enabled, the system policy `FullQcloudAccess` is bound by default** (allow-all). This repo adds Deny rules on top, ensuring safety.
- **Member policy attachment** (`org_member_policy_attachment`) accepts max 10 `member_uins` per resource. Split into multiple resources for larger account sets.
- **Login authorization** (`org_member_auth_identity_attachment`) allows max 5 identities per account.
- **Deleting member accounts**: To also deregister the Tencent Cloud account when deleting a Terraform-created member, add `force_delete_account = true` to the resource.
- **Inviting existing accounts**: Invited accounts require acceptee confirmation via Control Center console. This repo creates new accounts.
- **Payment delegation**: `member_permission_ids` containing `7` (delegation) requires `pay_uin` to be set.
- Organization/Control Center are global services; `region` is only used for region-specific resources in baselines.

## Provider Version

Account Factory baseline resources are available since tencentcloud provider v1.82.44. `versions.tf` requires `>= 1.82.50`.
