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
| `examples/` | Runnable scenario examples (`minimal` / `complete`) |
| `scripts/tests/` | Preflight unit tests (pytest) |
| `VERSION` / `CHANGELOG.md` | Release version and change history (Keep a Changelog) |
| `CONTRIBUTING.md` / `SECURITY.md` / `CODEOWNERS` | Contribution conventions, vulnerability reporting, ownership |
| `.terraform-docs.yml` / `.tflint.hcl` / `.pre-commit-config.yaml` | Docs generation, lint and pre-commit tooling configuration |
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

- **CI Validation**: `.github/workflows/terraform-ci.yml` runs `fmt -check`, `validate`, tflint, config preflight, preflight unit tests (pytest), scenario example validation and advisory checkov/trivy security scans on every PR/push; a docs check fails the build if the generated module reference drifts from the README. The plan step auto-enables after configuring `TENCENTCLOUD_SECRET_ID` / `TENCENTCLOUD_SECRET_KEY` in repository Settings → Secrets (skips if not configured).
- **Drift Detection**: `.github/workflows/drift-detection.yml` runs `terraform plan -detailed-exitcode` weekly; the job fails and notifies when manual console operations have drifted the environment. Requires the credentials above and a committed remote backend (`backend.tf`).
- **Convergence**: review detected drift manually, then run `terraform apply` to converge back to the codified state.

## Known Limitations

- Department nesting is capped at **3 levels** (root → L1 → L2 → L3); deeper structures are rejected by the check blocks.
- Member accounts are **created**, not invited. Inviting existing accounts requires the invitee's confirmation in the Control Center console.
- Central audit logging needs a **one-time manual CAM role** in the log archive account — no organization API can create it from the management account. The bucket must also authorize the CloudAudit service to write.
- The security scans (checkov / trivy) are **advisory**: their rulesets primarily target AWS/Azure/GCP and cover Tencent Cloud resources only partially.
- CI authentication uses long-lived credentials from repository Secrets; an OIDC-based bootstrap stage is on the [roadmap](ROADMAP.md).

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

## Module Reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.5 |
| tencentcloud | >= 1.82.50 |

## Providers

| Name | Version |
| ---- | ------- |
| tencentcloud | 1.83.21 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| audit\_logging | ./modules/audit-logging | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [tencentcloud_batch_apply_account_baselines.all](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/batch_apply_account_baselines) | resource |
| [tencentcloud_controlcenter_account_factory_baseline_config.default](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/controlcenter_account_factory_baseline_config) | resource |
| [tencentcloud_organization_instance.this](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_instance) | resource |
| [tencentcloud_organization_org_identity.admin_login](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_identity) | resource |
| [tencentcloud_organization_org_identity.auditor](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_identity) | resource |
| [tencentcloud_organization_org_identity.security_ops](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_identity) | resource |
| [tencentcloud_organization_org_manage_policy.this](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_manage_policy) | resource |
| [tencentcloud_organization_org_manage_policy_config.scp](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_manage_policy_config) | resource |
| [tencentcloud_organization_org_manage_policy_target.this](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_manage_policy_target) | resource |
| [tencentcloud_organization_org_member.business](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_member) | resource |
| [tencentcloud_organization_org_member.core](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_member) | resource |
| [tencentcloud_organization_org_member_auth_identity_attachment.admin_login](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_member_auth_identity_attachment) | resource |
| [tencentcloud_organization_org_member_policy_attachment.auditor](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_member_policy_attachment) | resource |
| [tencentcloud_organization_org_member_policy_attachment.security_ops](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_member_policy_attachment) | resource |
| [tencentcloud_organization_org_node.level2](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_node) | resource |
| [tencentcloud_organization_org_node.level3](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_node) | resource |
| [tencentcloud_organization_org_node.this](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/organization_org_node) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| audit\_log\_bucket\_name | Audit log COS bucket name (without the -APPID suffix, globally unique); required when enable\_central\_logging = true | `string` | `null` | no |
| audit\_log\_retention\_days | Audit log retention in days, expired objects are deleted by a COS lifecycle rule; 0 keeps logs forever | `number` | `365` | no |
| baseline\_config\_items | Account factory baseline item list (identifier + configuration JSON); add or remove as needed.<br/>Identifiers can be listed via data source tencentcloud\_controlcenter\_account\_factory\_baseline\_items. | <pre>list(object({<br/>    identifier    = string<br/>    configuration = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "configuration": "{\n  \"TagValuePairs\": [\n    { \"Key\": \"Environment\", \"Values\": [\"managed\"] }\n  ]\n}\n",<br/>    "identifier": "TCC-AF_PRESET_TAG"<br/>  },<br/>  {<br/>    "configuration": "{\n  \"VpcName\": \"default-vpc\",\n  \"CidrBlock\": \"10.0.0.0/16\",\n  \"Region\": 1,\n  \"RegionName\": \"ap-guangzhou\",\n  \"Subnets\": [\n    { \"CidrBlock\": \"10.0.1.0/24\", \"SubnetName\": \"app\", \"Zone\": \"ap-guangzhou-6\" },\n    { \"CidrBlock\": \"10.0.2.0/24\", \"SubnetName\": \"db\",  \"Zone\": \"ap-guangzhou-6\" }\n  ]\n}\n",<br/>    "identifier": "TCC-AF_VPC_SUBNET"<br/>  }<br/>]</pre> | no |
| baseline\_name | Account factory baseline name; must be unique | `string` | `"default"` | no |
| business\_accounts | Business/sandbox accounts. Map key is the resource identifier; department must be a departments key.<br/>Maps to the "Account Creation / Invitation" section of the Control Center Landing Zone. | <pre>map(object({<br/>    name       = string<br/>    remark     = string<br/>    department = string<br/>  }))</pre> | <pre>{<br/>  "app-prod": {<br/>    "department": "business",<br/>    "name": "AppA-Production",<br/>    "remark": "Production business account"<br/>  },<br/>  "dev-test": {<br/>    "department": "sandbox",<br/>    "name": "DevTest",<br/>    "remark": "Sandbox test account"<br/>  }<br/>}</pre> | no |
| core\_accounts | Core accounts (key accounts managed by the management account), mapping to the<br/>"Core Accounts" section of the Control Center Landing Zone.<br/>Each element: key (resource identifier), name, department (must be a departments key), remark. | <pre>list(object({<br/>    key        = string<br/>    name       = string<br/>    department = string<br/>    remark     = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "department": "core",<br/>    "key": "security",<br/>    "name": "Security",<br/>    "remark": "Centralized security products (WAF, host security, etc.)"<br/>  },<br/>  {<br/>    "department": "core",<br/>    "key": "logging",<br/>    "name": "Logging",<br/>    "remark": "Centralized collection of operation audit and config audit logs"<br/>  },<br/>  {<br/>    "department": "core",<br/>    "key": "finance",<br/>    "name": "Finance",<br/>    "remark": "Finance reconciliation and cost analysis"<br/>  }<br/>]</pre> | no |
| departments | Department (organizational unit) list. key is the resource identifier, name is the display name.<br/>Maps to the "Departments" section of the Control Center Landing Zone.<br/>parent is optional: set it to another department key to create a sub-department<br/>(up to 3 levels: root -> L1 -> L2 -> L3); null (default) attaches to the organization root. | <pre>list(object({<br/>    key    = string<br/>    name   = string<br/>    remark = string<br/>    parent = optional(string, null)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "key": "core",<br/>    "name": "Core",<br/>    "remark": "Hosts security, logging and finance core accounts"<br/>  },<br/>  {<br/>    "key": "business",<br/>    "name": "Business",<br/>    "remark": "Production business accounts"<br/>  },<br/>  {<br/>    "key": "sandbox",<br/>    "name": "Sandbox",<br/>    "remark": "Test and experiment accounts; must not host production workloads"<br/>  }<br/>]</pre> | no |
| enable\_auditor\_policy | Whether to bind the read-only auditor identity to all accounts | `bool` | `true` | no |
| enable\_baselines | Whether to configure and batch-apply account factory baselines; false disables the whole baseline module | `bool` | `true` | no |
| enable\_central\_logging | Whether to create an organization-wide CloudAudit track (track\_for\_all\_members) delivering all member operation logs to a COS bucket in the log archive account | `bool` | `false` | no |
| enable\_guardrails | Whether to create and attach guardrails (Service Control Policies); false disables the whole guardrail module | `bool` | `true` | no |
| enable\_login\_permission | Whether to allow the management account to log in to business accounts as administrator (login authorization) | `bool` | `true` | no |
| guardrail\_policies | Guardrail (SCP) map. Map key is the policy name; bound\_to lists department keys<br/>to attach (must be departments keys). content is a CAM policy syntax JSON document. | <pre>map(object({<br/>    description = string<br/>    content     = string<br/>    bound_to    = list(string)<br/>  }))</pre> | <pre>{<br/>  "DenyDeleteCoreNetwork": {<br/>    "bound_to": [<br/>      "business"<br/>    ],<br/>    "content": "{\n  \"version\": \"2.0\",\n  \"statement\": [\n    {\n      \"effect\": \"deny\",\n      \"action\": [\n        \"vpc:DeleteVpc\",\n        \"vpc:DeleteSubnet\",\n        \"vpc:DeleteNatGateway\",\n        \"vpc:DeleteVpnGateway\"\n      ],\n      \"resource\": [\"*\"]\n    }\n  ]\n}\n",<br/>    "description": "Deny deleting core network resources such as VPCs, subnets and NAT gateways"<br/>  },<br/>  "DenyDeleteSecurityResources": {<br/>    "bound_to": [<br/>      "business"<br/>    ],<br/>    "content": "{\n  \"version\": \"2.0\",\n  \"statement\": [\n    {\n      \"effect\": \"deny\",\n      \"action\": [\n        \"cam:DeleteUser\",\n        \"cam:DeleteRole\",\n        \"cam:DeletePolicy\",\n        \"cloudaudit:DeleteAudit\",\n        \"cloudaudit:StopLogging\",\n        \"cloudaudit:DeleteAuditTrack\",\n        \"cloudaudit:ModifyAuditTrack\",\n        \"config:DeleteConfigRule\",\n        \"cls:DeleteLogset\",\n        \"cls:DeleteTopic\",\n        \"cos:DeleteBucket\"\n      ],\n      \"resource\": [\"*\"]\n    }\n  ]\n}\n",<br/>    "description": "Deny deleting CAM identities, audit, logging and storage resources to protect security and compliance assets"<br/>  },<br/>  "DenyOrganizationTampering": {<br/>    "bound_to": [<br/>      "core",<br/>      "business",<br/>      "sandbox"<br/>    ],<br/>    "content": "{\n  \"version\": \"2.0\",\n  \"statement\": [\n    {\n      \"effect\": \"deny\",\n      \"action\": [\n        \"organization:QuitOrganization\",\n        \"organization:DeleteOrganizationMembers\",\n        \"organization:DeleteOrganizationNodes\",\n        \"organization:MoveOrganizationNode\",\n        \"organization:UpdateOrganizationNode\",\n        \"organization:UpdateOrganizationMembers\"\n      ],\n      \"resource\": [\"*\"]\n    }\n  ]\n}\n",<br/>    "description": "Deny member accounts quitting the organization or mutating organization members/nodes; structure changes are reserved for the management account"<br/>  }<br/>}</pre> | no |
| log\_archive\_account\_key | Key of the log archive account in core\_accounts (its UIN is used as the audit log storage account) | `string` | `"logging"` | no |
| log\_archive\_appid | APPID of the log archive account (COS bucket names require the -APPID suffix); required when enable\_central\_logging = true | `string` | `null` | no |
| log\_archive\_role\_name | Name of the CAM role pre-created in the log archive account; the management account assumes it to create/maintain the COS bucket | `string` | `"LandingZoneLogArchiveAccess"` | no |
| member\_permission\_ids | Member finance permissions (maps to the Landing Zone "Finance" section):<br/>1 view bills, 2 view balance, 3 fund transfer, 4 consolidated billing,<br/>5 invoicing, 6 discount inheritance, 7 delegated payment.<br/>Must include 1 and 2; pay\_uin is required when 7 is included. | `list(number)` | <pre>[<br/>  1,<br/>  2,<br/>  4<br/>]</pre> | no |
| pay\_uin | Delegated payment account UIN; only required when member\_permission\_ids includes 7 | `string` | `null` | no |
| region | Tencent Cloud region. Organization / Control Center are global services; this is only used for regional resources (e.g. the baseline VPC) | `string` | `"ap-guangzhou"` | no |
| root\_node\_name | Organization root node name (root department under the management account) | `string` | `"Root"` | no |
| tags | Global tags applied to taggable resources | `map(string)` | <pre>{<br/>  "ManagedBy": "Terraform",<br/>  "Purpose": "LandingZone"<br/>}</pre> | no |
| tencentcloud\_secret\_id | Tencent Cloud API SecretId; leave null to use the TENCENTCLOUD\_SECRET\_ID environment variable | `string` | `null` | no |
| tencentcloud\_secret\_key | Tencent Cloud API SecretKey; leave null to use the TENCENTCLOUD\_SECRET\_KEY environment variable | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| audit\_log\_bucket | Central audit log COS bucket, full name with -APPID suffix (null when enable\_central\_logging = false) |
| baseline\_id | Account factory baseline configuration ID (null when enable\_baselines = false) |
| business\_account\_uins | Business/sandbox account UINs |
| core\_account\_uins | Core account UINs, keyed by core\_accounts key |
| department\_nodes | Department (organizational unit) IDs, keyed by departments key (including nested sub-departments) |
| identity\_ids | Custom identity (permission set) IDs |
| manage\_policy\_ids | Guardrail (SCP) policy IDs, keyed by guardrail\_policies policy name |
| organization\_id | Organization (group account management) ID |
| root\_node\_id | Organization root node ID |
<!-- END_TF_DOCS -->

## License

[Apache-2.0](LICENSE)
