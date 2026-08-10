# tencentcloud-landingzone

Terraform implementation of Tencent Cloud Control Center Landing Zone best practices. Deploys multi-account cloud environment **organization, core accounts, finance, identities, guardrails, and account baselines** in a versionable, auditable, repeatable way.

基于腾讯云控制中心（Control Center，产品文档 [1220/57785](https://intl.cloud.tencent.com/zh/document/product/1220/57785)）Landing Zone 最佳实践，用 Terraform 将多账号云环境的**组织架构、核心账号、财务、身份权限、防护规则、账号基线**一次性落地，可版本化、可审计、可重复执行。

## Architecture / 架构

```
                    ┌──────────────────────────────┐
                    │  Management Account (terraform)│
                    │  管理账号（执行 terraform）      │
                    └──────────────┬───────────────┘
                                   │ Enable Organization
                                   │ 开通组织服务
                    ┌──────────────▼───────────────┐
                    │  Organization Service         │
                    │  集团账号管理（Organization）   │
                    └──────────────┬───────────────┘
                                   │
        ┌──────────────┬───────────┴───────────┬──────────────┐
        │              │                       │              │
   ┌────▼────┐   ┌─────▼─────┐          ┌──────▼─────┐   ┌────▼─────┐
   │ Core     │   │ Business │          │ Sandbox    │   │ Guardrails│
   │ Accounts │   │ Division │          │ Division   │   │ (SCP)     │
   │ 核心账号  │   │ 业务部门  │          │ 沙箱环境   │   │ 防护规则  │
   │ 安全/日志│   │ 生产业务  │          │ 测试实验   │   │ 绑定部门  │
   │ 财务     │   │ 账号     │          │ 账号      │   │           │
   └────┬────┘   └─────┬─────┘          └──────┬─────┘   └──────────┘
        │              │                       │
        └──────┬───────┴───────────┬───────────┘
               │                   │
        ┌──────▼──────┐    ┌───────▼────────┐
        │ Identities   │    │ Account Factory │
        │ & Permissions│    │ Baselines       │
        │ 身份与权限    │    │ 标签/VPC/联系人   │
        │ 权限集/成员   │    │ 批量应用到账号    │
        │ 策略/登录授权 │    │                │
        └─────────────┘    └────────────────┘
```

## Configuration Mapping / 配置映射

Maps to the 8 Control Center Landing Zone configuration areas:

对应控制中心 Landing Zone 的 8 项配置：

| Control Center Config / 控制中心配置 | Implementation / 本仓库实现 | Terraform Resource |
|---|---|---|
| Departments / 部门 | `organization.tf` | `tencentcloud_organization_org_node` |
| Core Accounts / 核心账号 | `organization.tf` | `tencentcloud_organization_org_member` |
| Account Creation & Invitation / 账号创建/邀请 | `organization.tf` | `tencentcloud_organization_org_member` |
| Finance / 财务 | `organization.tf` + `variables.tf` | `permission_ids`, `pay_uin` |
| Identities & Permissions / 身份与权限 | `identities.tf` | `org_identity` / `org_member_policy_attachment` / `org_member_auth_identity_attachment` |
| Guardrails / 防护规则 | `guardrails.tf` | `org_manage_policy` + `org_manage_policy_target` |
| Baseline Management / 基线管理 | `baselines.tf` | `controlcenter_account_factory_baseline_config` + `batch_apply_account_baselines` |
| Compliance Audit (Log Shipping) / 合规审计（日志投递） | See notes below / 见下方说明 | Configure CloudAudit / Config shipping in log account |

> Log shipping (CloudAudit / Config logs to COS) requires enabling services within the log account. This can be done via console or `tencentcloud_audit` resources. The log account created by this repo is ready to host these configurations.
>
> 合规审计日志投递（云审计/配置审计日志投递到 COS）需要在日志账号内开通对应服务，可通过控制台或 `tencentcloud_audit` 等资源在日志账号中配置，本仓库在日志账号中预留承载。

## Files / 文件说明

| File / 文件 | Description / 说明 |
|---|---|
| `main.tf` | Provider config, enable organization service / Provider 配置、开通组织服务 |
| `organization.tf` | Departments, core/business/sandbox accounts, finance / 部门、核心/业务/沙箱账号、财务 |
| `identities.tf` | Identities (permission sets), policy attachments, login authorization / 身份、成员策略绑定、登录授权 |
| `guardrails.tf` | Service Control Policies (SCP) and bindings / 防护规则（服务控制策略）创建与绑定 |
| `baselines.tf` | Account factory baseline configs and batch application / 账号工厂基线配置与批量应用 |
| `variables.tf` / `outputs.tf` | Input variables and outputs / 输入变量与输出 |
| `terraform.tfvars.example` | Variable examples / 变量示例 |
| `scripts/validate-config.py` | Config preflight: validates tfvars reference consistency before apply / 配置预检：apply 前校验引用一致性 |
| `.github/workflows/terraform-ci.yml` | CI: fmt + validate + preflight + optional plan / CI：fmt + validate + 预检 + 可选 plan |

## Prerequisites / 前置条件

- Management account has completed **enterprise real-name verification** (Control Center only supports enterprise accounts) / 管理账号已完成**企业实名认证**（控制中心仅支持企业账号，个人账号不支持）
- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.3 installed locally / 本地安装 Terraform ≥ 1.3
- Configure Tencent Cloud API credentials (choose one) / 配置腾讯云 API 凭证（二选一）：
  - Environment variables / 环境变量：`export TENCENTCLOUD_SECRET_ID=... TENCENTCLOUD_SECRET_KEY=...`
  - `terraform.tfvars`: copy `terraform.tfvars.example` and fill in / 复制 `terraform.tfvars.example` 并填写
- Preflight script requires `python3` + `python-hcl2`: `pip install python-hcl2` (auto-installed in CI) / 运行预检脚本需 `python3` + `python-hcl2`（CI 已自动安装）

## Quick Start / 快速开始

```bash
cp terraform.tfvars.example terraform.tfvars   # Customize as needed / 按需修改
terraform init
terraform plan                                 # Review changes / 确认变更
terraform apply
```

First `apply` will sequentially: enable organization → create departments → create core/business accounts → create identities and bind → enable SCP and bind → configure baselines and apply to all accounts.

首次 `apply` 会依次：开通组织 → 创建部门 → 创建核心/业务账号 → 创建身份并绑定 → 开启 SCP 并绑定 → 配置基线并批量应用。

## Default Account Structure / 默认账号结构

```
Root Management Account / 集团根账号（管理账号）
├── Core Accounts / 核心账号
│   ├── Security Account     # Centralized security products / 集中部署安全产品
│   ├── Log Account          # Centralized audit log collection / 集中收集审计日志
│   └── Finance Account      # Finance reconciliation & cost analysis / 财务对账与成本分析
├── Business Division / 业务部门
│   └── AppA-Production
└── Sandbox Division / 沙箱环境
    └── DevTest / 开发测试
```

Adjust structure by modifying `departments` / `core_accounts` / `business_accounts` in `variables.tf`.

按需修改 `variables.tf` 中的 `departments` / `core_accounts` / `business_accounts` 即可调整结构。

## Extension & Trimming / 扩展与裁剪

Data-driven design with feature flags. **Modify `terraform.tfvars` only — no code changes needed.**

数据驱动 + 模块开关设计。**改 `terraform.tfvars` 即可完成扩展与裁剪，无需改代码**：

| Requirement / 需求 | Approach / 做法 |
|---|---|
| Disable a module / 整体裁剪某个模块 | Set `enable_guardrails` / `enable_baselines` / `enable_login_permission` / `enable_auditor_policy` to `false` |
| Add/remove divisions or accounts / 增删部门/账号 | Modify `departments` / `core_accounts` / `business_accounts` |
| Add/remove SCP guardrails / 增删防护规则（SCP） | Modify `guardrail_policies` map (includes `bound_to` binding targets) |
| Add/remove baseline items / 增删基线项 | Modify `baseline_config_items` list |
| Adjust finance permissions / 调整财务权限/代付 | Modify `member_permission_ids` / `pay_uin` |
| Add/remove identities / 增删身份（权限集） | Copy/delete identity resource blocks and bindings in `identities.tf` |

Minimal example (organization + accounts only, no governance modules):

极端裁剪示例（仅组织 + 账号，不启用任何治理模块）：

```hcl
enable_guardrails       = false
enable_baselines        = false
enable_login_permission = false
enable_auditor_policy   = false
```

## Phased Deployment / 分阶段部署

For first-time deployment, apply in dependency order to reduce blast radius and verify each stage:

首次落地建议按依赖顺序分阶段 apply，降低单次变更面、便于逐段验证：

| Stage / 阶段 | Content / 内容 | Command / 命令 |
|---|---|---|
| 1 Org & Accounts | Enable org, departments, core/business accounts / 开通组织、部门、核心/业务账号 | `terraform apply -target=tencentcloud_organization_instance.this -target=tencentcloud_organization_org_node.this -target=tencentcloud_organization_org_member.core -target=tencentcloud_organization_org_member.business` |
| 2 Identities & Guardrails | Identities, policy bindings, login auth, SCP / 身份、成员策略、登录授权、SCP | `terraform apply -target=tencentcloud_organization_org_identity.* -target=tencentcloud_organization_org_member_policy_attachment.* -target=tencentcloud_organization_org_member_auth_identity_attachment.* -target=tencentcloud_organization_org_manage_policy.*` |
| 3 Baselines | Account factory baselines + batch apply / 账号工厂基线配置 + 批量应用 | `terraform apply -target=tencentcloud_controlcenter_account_factory_baseline_config.default -target=tencentcloud_batch_apply_account_baselines.all` |
| 4 Finalize | Full reconciliation / 全量核对，补遗漏 | `terraform apply` |

> After each stage, run `terraform plan` to confirm no unexpected changes before proceeding. With many accounts, pilot 1-2 business accounts first with `-target` to validate baseline effects, then apply fully.
>
> 每个阶段结束后 `terraform plan` 检查无意外变更再进入下一阶段。账号较多时建议先用 `-target` 试点 1-2 个业务账号验证基线效果，再全量 apply。

## Continuous Governance / 持续治理

- **CI Validation**: `.github/workflows/terraform-ci.yml` runs `fmt -check`, `validate`, and config preflight on every PR/push. Plan step auto-enables after configuring `TENCENTCLOUD_SECRET_ID` / `TENCENTCLOUD_SECRET_KEY` in repository Settings → Secrets (skips if not configured).

  **CI 校验**：`.github/workflows/terraform-ci.yml` 在 PR / push 时自动执行 `fmt -check`、`validate`、配置预检；在仓库 Settings → Secrets 配置 `TENCENTCLOUD_SECRET_ID` / `TENCENTCLOUD_SECRET_KEY` 后，plan 步骤自动启用（不配置则跳过）。

- **Drift Detection**: Landing Zone compliance may drift due to manual console operations (e.g., manually changing departments or binding policies). Run `terraform plan` periodically and compare with CI results; converge drift with `terraform apply`.

  **漂移检测**：Landing Zone 的合规性会随控制台人工操作漂移（如手工改了部门、绑定了策略）。建议定期执行 `terraform plan` 并与 CI 对比，发现 drift 后 `terraform apply` 收敛。

- **Preflight Script**: Run `python3 scripts/validate-config.py` before apply to quickly catch department reference, finance permission, binding target, and other configuration errors — avoiding mid-plan failures.

  **预检脚本**：apply 前先跑 `python3 scripts/validate-config.py`，快速发现部门引用、财务权限、绑定目标等配置错误，避免 plan 到中途才报错。

## Baseline Items / 基线项说明

`baselines.tf` is driven by `var.baseline_config_items`. Defaults include two account factory baseline items (extensible):

`baselines.tf` 由 `var.baseline_config_items` 驱动，默认包含两个账号工厂基线项（可增删）：

- `TCC-AF_PRESET_TAG`: Preset tag baseline for uniform management tags across all accounts / 预设标签基线，给所有账号统一打管理标签
- `TCC-AF_VPC_SUBNET`: VPC/subnet baseline creating default network per account / VPC/子网基线，为账号创建默认网络

Query available baseline items and their configuration schema via console or:

可用基线项及其配置结构可通过控制台或如下 data source 查询：

```hcl
data "tencentcloud_controlcenter_account_factory_baseline_items" "all" {}
```

Other common baseline items: `TCC-AF_SHARE_IMAGE` (shared image), `ACS-BP_ACCOUNT_FACTORY_ACCOUNT_CONTACT` (account contact).

其他常见基线项：`TCC-AF_SHARE_IMAGE`（共享镜像）、`ACS-BP_ACCOUNT_FACTORY_ACCOUNT_CONTACT`（账号联系人）。

## Notes / 注意事项

- **SCP defines permission boundaries only, does not grant permissions**: Effective permissions = SCP ∩ CAM permissions within the account. CAM still needs to be configured inside each member account.

  **SCP 只定义权限边界，不授予权限**：成员账号的最终权限 = 组织 SCP ∩ 账号内 CAM 权限，仍需在账号内配置 CAM。

- **After SCP is enabled, the system policy `FullQcloudAccess` is bound by default** (allow-all). This repo adds Deny rules on top, ensuring safety.

  **SCP 启用后默认绑定系统策略 FullQcloudAccess**（全放行），本仓库在此基础上追加 Deny 规则，安全可控。

- **Member policy attachment** (`org_member_policy_attachment`) accepts max 10 `member_uins` per resource. Split into multiple resources for larger account sets.

  **成员策略绑定**（`org_member_policy_attachment`）的 `member_uins` 单次最多 10 个，账号多时请拆分。

- **Login authorization** (`org_member_auth_identity_attachment`) allows max 5 identities per account.

  **登录授权**（`org_member_auth_identity_attachment`）单账号最多绑定 5 个身份。

- **Deleting member accounts**: To also deregister the Tencent Cloud account when deleting a Terraform-created member, add `force_delete_account = true` to the resource.

  **删除成员账号**：删除由 Terraform 创建的成员时，如需连带注销腾讯云账号，给资源加 `force_delete_account = true`。

- **Inviting existing accounts**: Invited accounts require acceptee confirmation via Control Center console. This repo creates new accounts.

  **邀请已有账号**：邀请型账号需对方同意，请在控制中心完成邀请；本仓库创建的是新账号。

- **Payment delegation**: `member_permission_ids` containing `7` (delegation) requires `pay_uin` to be set.

  **代付**：`member_permission_ids` 包含 `7`（代付）时必须设置 `pay_uin`。

- Organization/Control Center are global services; `region` is only used for region-specific resources in baselines.

  组织/控制中心为全局服务，`region` 仅用于基线中的地域性资源。

## Provider Version / Provider 版本

Account Factory baseline resources are available since tencentcloud provider v1.82.44. `versions.tf` requires `>= 1.82.50`.

控制中心（Control Center）账号工厂基线资源自 tencentcloud provider v1.82.44 提供，`versions.tf` 已要求 `>= 1.82.50`。
