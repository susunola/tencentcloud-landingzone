<p align="center">
  <b>English</b> &nbsp;|&nbsp;
  <a href="README.zh-CN.md">简体中文</a>
</p>

# tencentcloud-landingzone

Terraform implementation of Tencent Cloud Control Center Landing Zone best practices. Deploys a multi-account cloud environment — **organization (with nested departments), core accounts, finance, identities, guardrails, account baselines, and central audit logging** — in a versionable, auditable, repeatable way.

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
   │ Security │   │ (nested  │          │ Dev/Test   │   │ Bound to  │
   │ Logging  │   │  sub-    │          │            │   │ divisions │
   │ Finance  │   │  divs)   │          │            │   │           │
   └────┬────┘   └─────┬─────┘          └──────┬─────┘   └──────────┘
        │              │                       │
        └──────┬───────┴───────────┬───────────┘
               │                   │
        ┌──────▼──────┐    ┌───────▼────────┐    ┌──────────────────┐
        │ Identities   │    │ Account Factory │    │ Central Audit     │
        │ & Permissions│    │ Baselines       │    │ Logging (opt-in)  │
        │ Permission   │    │ Tags/VPC/       │    │ Org-wide          │
        │ Sets/Members │    │ Contacts        │    │ CloudAudit track  │
        │ Policies/    │    │ Batch apply     │    │ -> log account    │
        │ Login Auth   │    │ to accounts     │    │    COS bucket     │
        └─────────────┘    └────────────────┘    └──────────────────┘
```

## Configuration Mapping

Maps to the 8 Control Center Landing Zone configuration areas:

| Control Center Config | Implementation | Terraform Resource |
|---|---|---|
| Departments | `organization.tf` | `tencentcloud_organization_org_node` (nesting supported) |
| Core Accounts | `organization.tf` | `tencentcloud_organization_org_member` |
| Account Creation & Invitation | `organization.tf` | `tencentcloud_organization_org_member` |
| Finance | `organization.tf` + `variables.tf` | `permission_ids`, `pay_uin` |
| Identities & Permissions | `identities.tf` | `org_identity` / `org_member_policy_attachment` / `org_member_auth_identity_attachment` |
| Guardrails | `guardrails.tf` | `org_manage_policy` + `org_manage_policy_target` |
| Baseline Management | `baselines.tf` | `controlcenter_account_factory_baseline_config` + `batch_apply_account_baselines` |
| Compliance Audit (Log Shipping) | `logging.tf` + `modules/audit-logging` | `tencentcloud_audit_track` (organization-wide) + `tencentcloud_cos_bucket` |

## Files

| File | Description |
|---|---|
| `main.tf` | Provider config, enable organization service |
| `organization.tf` | Departments (`parent` nesting, up to 3 levels), core/business/sandbox accounts, finance |
| `identities.tf` | Identities (permission sets), policy attachments, login authorization |
| `guardrails.tf` | Service Control Policies (SCP) and attachments |
| `baselines.tf` | Account factory baseline configs and batch application |
| `logging.tf` | Central audit logging (opt-in): log account provider alias + audit module |
| `locals.tf` | Shared locals: member account set and UIN chunking (10 per call) |
| `checks.tf` | Native check blocks: reference consistency fails at plan time |
| `modules/audit-logging/` | Audit logging module: log archive COS bucket + organization-wide CloudAudit track |
| `variables.tf` / `outputs.tf` | Input variables (with native validations) and outputs |
| `terraform.tfvars.example` | Variable examples |
| `backend.tf.example` | COS remote state example (with locking); copy to `backend.tf` to enable |
| `scripts/validate-config.py` | Config preflight: validates tfvars reference consistency before apply |
| `Makefile` | Command entry points and staged deployment (`make help`) |
| `.github/workflows/terraform-ci.yml` | CI: fmt + validate + preflight + optional plan + checkov scan |
| `.github/workflows/drift-detection.yml` | Scheduled drift detection (weekly; requires credentials and remote backend) |

## Prerequisites

- Management account has completed **enterprise real-name verification** (Control Center only supports enterprise accounts)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.5 installed locally
- Configure Tencent Cloud API credentials (choose one):
  - Environment variables: `export TENCENTCLOUD_SECRET_ID=... TENCENTCLOUD_SECRET_KEY=...`
  - `terraform.tfvars`: copy `terraform.tfvars.example` and fill in
- Preflight script requires `python3` + `python-hcl2`: `pip install python-hcl2` (auto-installed in CI)

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars   # Customize as needed
terraform init
terraform plan                                 # Review changes (check blocks report config errors here)
terraform apply
```

Or use the Makefile: `make plan` / `make apply` / `make stage1..4` (see `make help`).

First `apply` will sequentially: enable organization → create departments (including nested ones) → create core/business accounts → create identities and bind → enable SCP and attach → configure baselines and batch-apply.

## Default Account Structure

```
Root Management Account
├── Core Accounts
│   ├── Security Account     # Centralized security products
│   ├── Log Account          # Centralized audit log collection (audit log archive)
│   └── Finance Account      # Finance reconciliation & cost analysis
├── Business Division
│   └── AppA-Production
└── Sandbox Division
    └── DevTest
```

## Nested Departments

`departments` entries accept an optional `parent` field pointing to another department key, creating sub-departments (up to 3 levels):

```hcl
departments = [
  { key = "core",     name = "Core",     remark = "Hosts security, logging and finance core accounts" },
  { key = "business", name = "Business", remark = "All business accounts" },
  { key = "prod",     name = "Prod",     remark = "Production",  parent = "business" }, # L2
  { key = "proj-x",   name = "ProjectX", remark = "Key project", parent = "prod" },      # L3
]
```

- Account `department` and guardrail `bound_to` may reference departments at any level.
- Dangling parents, self-references, cycles and nesting deeper than 3 levels are reported by both the plan-time check blocks and the preflight script.
- Upgrading from older versions: flat departments are treated as L1 and resource addresses are unchanged (`org_node.this`), so **no state migration is needed**.

## State Management (Remote Backend)

For team collaboration or CI, always enable remote state:

1. Create a COS bucket once (versioning, default encryption and private ACL recommended).
2. `cp backend.tf.example backend.tf` and fill in bucket / prefix / region.
3. `terraform init -migrate-state` to move the local state into COS.

The COS backend is built into Terraform and supports state locking (see the [Terraform docs](https://developer.hashicorp.com/terraform/language/backend/cos)).

## Central Audit Logging (opt-in)

- Creates a COS bucket in the **log archive account** (versioning + AES256 encryption + retention lifecycle).
- Creates an organization-wide CloudAudit track in the **management account** (`track_for_all_members = 1`), delivering operation logs of every member account to that bucket.

**Prerequisite (one-time manual step):** log in to the log archive account console via login authorization (the `OrganizationAdmin` identity) and create a CAM role (default name `LandingZoneLogArchiveAccess`) trusting the management account UIN, with COS permissions (`QcloudCOSFullAccess` recommended).

Then enable it in tfvars:

```hcl
enable_central_logging   = true
audit_log_bucket_name    = "my-org-audit-logs"   # without the -APPID suffix
log_archive_appid        = "1300xxxxxx"
audit_log_retention_days = 365                    # 0 = keep forever
```

> If log delivery fails, check that the log archive bucket grants write access to the CloudAudit service (one-click authorization is available on the CloudAudit console page).

## Extension & Trimming

Data-driven design with feature flags. **Modify `terraform.tfvars` only — no code changes needed.**

| Requirement | Approach |
|---|---|
| Disable a module | Set `enable_guardrails` / `enable_baselines` / `enable_login_permission` / `enable_auditor_policy` / `enable_central_logging` to `false` |
| Add/remove (nested) departments | Modify `departments` (`parent` controls the level, up to 3) |
| Add/remove accounts | Modify `core_accounts` / `business_accounts` |
| Add/remove SCP guardrails | Modify `guardrail_policies` map (includes `bound_to` attachment targets) |
| Add/remove baseline items | Modify `baseline_config_items` list |
| Adjust finance permissions | Modify `member_permission_ids` / `pay_uin` |
| Enable central audit logging | `enable_central_logging = true` + bucket name / APPID (prerequisite above) |
| Add/remove identities | Copy/delete identity resource blocks and bindings in `identities.tf` |

Minimal example (organization + accounts only, no governance modules):

```hcl
enable_guardrails       = false
enable_baselines        = false
enable_login_permission = false
enable_auditor_policy   = false
# enable_central_logging defaults to false
```

## Configuration Validation (Three Layers)

Configuration errors are caught before apply:

1. **Variable `validation` blocks** (`variables.tf`): fail at tfvars load time — region format, unique department keys, finance permissions including 1/2, guardrail content must be valid JSON, etc.
2. **`check` blocks** (`checks.tf`): fail at `terraform plan` — dangling/cyclic/too-deep department parents, account department references, guardrail attachment targets, missing `pay_uin`, missing audit logging bucket/APPID.
3. **Preflight script** (`scripts/validate-config.py`): standalone tfvars validation without Terraform, ideal for CI and quick local checks (`make preflight`).

## Phased Deployment

For first-time deployment, apply in dependency order to reduce blast radius and verify each stage (`make stage1` … `make stage4` run the same commands):

| Stage | Content | Command |
|---|---|---|
| 1 Org & Accounts | Enable org, departments (incl. nested), core/business accounts | `terraform apply -target=tencentcloud_organization_instance.this -target=tencentcloud_organization_org_node.this -target=tencentcloud_organization_org_node.level2 -target=tencentcloud_organization_org_node.level3 -target=tencentcloud_organization_org_member.core -target=tencentcloud_organization_org_member.business` |
| 2 Identities & Guardrails | Identities, policy bindings, login auth, SCP | `terraform apply -target=tencentcloud_organization_org_identity.* -target=tencentcloud_organization_org_member_policy_attachment.* -target=tencentcloud_organization_org_member_auth_identity_attachment.* -target=tencentcloud_organization_org_manage_policy.*` |
| 3 Baselines | Account factory baselines + batch apply | `terraform apply -target=tencentcloud_controlcenter_account_factory_baseline_config.default -target=tencentcloud_batch_apply_account_baselines.all` |
| 4 Finalize | Full reconciliation (incl. optional central audit logging) | `terraform apply` |

> After each stage, run `terraform plan` to confirm no unexpected changes before proceeding. With many accounts, pilot 1-2 business accounts first with `-target` to validate baseline effects, then apply fully.

## Continuous Governance

- **CI Validation**: `.github/workflows/terraform-ci.yml` runs `fmt -check`, `validate`, config preflight and an advisory checkov security scan on every PR/push. The plan step auto-enables after configuring `TENCENTCLOUD_SECRET_ID` / `TENCENTCLOUD_SECRET_KEY` in repository Settings → Secrets (skips if not configured).
- **Drift Detection**: `.github/workflows/drift-detection.yml` runs `terraform plan -detailed-exitcode` weekly; the job fails and notifies when manual console operations have drifted the environment. Requires the credentials above and a committed remote backend (`backend.tf`).
- **Convergence**: review detected drift manually, then run `terraform apply` to converge back to the codified state.

## Default Guardrails (SCP)

| Policy | Attached to | Description |
|---|---|---|
| `DenyOrganizationTampering` | core / business / sandbox | Deny member accounts quitting the organization or mutating organization members/nodes |
| `DenyDeleteSecurityResources` | business | Deny deleting CAM identities, CloudAudit (incl. tracks), Config, logging and COS storage resources |
| `DenyDeleteCoreNetwork` | business | Deny deleting core network resources such as VPCs, subnets and NAT gateways |

Add or remove map entries in `guardrail_policies` to extend; `bound_to` supports departments at any level.

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
- **Batch APIs are chunked automatically**: member policy attachment and baseline batch application accept max 10 UINs per call; `locals.tf` chunks the lists, so more than 10 accounts need no manual splitting.
- **Login authorization** (`org_member_auth_identity_attachment`) allows max 5 identities per account.
- **Deleting member accounts**: To also deregister the Tencent Cloud account when deleting a Terraform-created member, add `force_delete_account = true` to the resource.
- **Inviting existing accounts**: Invited accounts require acceptee confirmation via Control Center console. This repo creates new accounts.
- **Payment delegation**: `member_permission_ids` containing `7` (delegation) requires `pay_uin` to be set (enforced by a check block at plan time).
- Organization/Control Center are global services; `region` is only used for regional resources such as baselines and audit logging.

## Version Requirements

- Terraform ≥ 1.5 (check blocks)
- tencentcloud provider ≥ 1.82.50 (account factory baseline resources are available since v1.82.44)

## License

[Apache-2.0](LICENSE)
