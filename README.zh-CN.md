<p align="center">
  <a href="README.md">English</a> &nbsp;|&nbsp;
  <b>简体中文</b>
</p>

# tencentcloud-landingzone

基于腾讯云控制中心（Control Center，产品文档 [1220/57785](https://intl.cloud.tencent.com/zh/document/product/1220/57785)）Landing Zone 最佳实践，用 Terraform 将多账号云环境的**组织架构（含嵌套部门）、核心账号、财务、身份权限、防护规则、账号基线、集中审计日志**一次性落地，可版本化、可审计、可重复执行。

## 架构

```
                    ┌──────────────────────────────┐
                    │  管理账号（执行 terraform）    │
                    └──────────────┬───────────────┘
                                   │ 开通组织服务
                    ┌──────────────▼───────────────┐
                    │ 集团账号管理（Organization）   │
                    └──────────────┬───────────────┘
                                   │
        ┌──────────────┬───────────┴───────────┬──────────────┐
        │              │                       │              │
   ┌────▼────┐   ┌─────▼─────┐          ┌──────▼─────┐   ┌────▼─────┐
   │核心账号  │   │ 业务部门   │          │  沙箱环境   │   │ 防护规则  │
   │ 安全/日志│   │ 生产业务   │          │  测试实验   │   │ (SCP)    │
   │ 财务     │   │ (可嵌套子部门)│        │  账号      │   │ 绑定部门  │
   └────┬────┘   └─────┬─────┘          └──────┬─────┘   └──────────┘
        │              │                       │
        └──────┬───────┴───────────┬───────────┘
               │                   │
        ┌──────▼──────┐    ┌───────▼────────┐    ┌──────────────────┐
        │ 身份与权限    │    │  账号工厂基线    │    │ 集中审计日志(可选)  │
        │ 权限集/成员   │    │  标签/VPC/联系人 │    │ 组织级云审计跟踪    │
        │ 策略/登录授权 │    │  批量应用到账号   │    │ → 日志账号 COS 桶  │
        └─────────────┘    └────────────────┘    └──────────────────┘
```

对应控制中心 Landing Zone 的 8 项配置：

| 控制中心配置 | 本仓库实现 | Terraform 资源 |
|---|---|---|
| 部门 | `organization.tf` | `tencentcloud_organization_org_node`（支持嵌套） |
| 核心账号 | `organization.tf` | `tencentcloud_organization_org_member` |
| 账号创建/邀请 | `organization.tf` | `tencentcloud_organization_org_member` |
| 财务 | `organization.tf` + `variables.tf` | 财务权限 `permission_ids`、代付 `pay_uin` |
| 身份与权限 | `identities.tf` | `org_identity` / `org_member_policy_attachment` / `org_member_auth_identity_attachment` |
| 防护规则 | `guardrails.tf` | `org_manage_policy` + `org_manage_policy_target` |
| 基线管理 | `baselines.tf` | `controlcenter_account_factory_baseline_config` + `batch_apply_account_baselines` |
| 合规审计（日志投递） | `logging.tf` + `modules/audit-logging` | `tencentcloud_audit_track`（组织级）+ `tencentcloud_cos_bucket` |

## 文件说明

| 文件 | 说明 |
|---|---|
| `main.tf` | Provider 配置、开通组织服务 |
| `organization.tf` | 部门（支持 `parent` 嵌套，最多 3 层）、核心账号、业务/沙箱账号、财务权限 |
| `identities.tf` | 身份（权限集）、成员策略绑定、登录授权 |
| `guardrails.tf` | 防护规则（服务控制策略）创建与绑定 |
| `baselines.tf` | 账号工厂基线配置与批量应用 |
| `logging.tf` | 集中审计日志（可选）：日志账号 provider alias + 审计日志模块 |
| `locals.tf` | 共享 locals：成员账号集合与 UIN 分批（单次上限 10 个） |
| `checks.tf` | Terraform 原生 check 块：plan 阶段即校验配置引用一致性 |
| `modules/audit-logging/` | 审计日志模块：日志账号 COS 桶 + 组织级云审计跟踪 |
| `variables.tf` / `outputs.tf` | 输入变量（含原生 validation）与输出 |
| `terraform.tfvars.example` | 变量示例 |
| `backend.tf.example` | COS 远端 state 示例（支持 locking），复制为 `backend.tf` 启用 |
| `scripts/validate-config.py` | 配置预检：apply 前校验 tfvars 引用一致性 |
| `Makefile` | 常用命令与分阶段部署入口（`make help`） |
| `.github/workflows/terraform-ci.yml` | CI：fmt + validate + 预检 + 可选 plan + checkov 扫描 |
| `.github/workflows/drift-detection.yml` | 定时漂移检测（每周一，需配置凭证与远端 backend） |

## 前置条件

- 管理账号已完成**企业实名认证**（控制中心仅支持企业账号，个人账号不支持）
- 本地安装 [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.5
- 配置腾讯云 API 凭证（二选一）：
  - 环境变量：`export TENCENTCLOUD_SECRET_ID=... TENCENTCLOUD_SECRET_KEY=...`
  - `terraform.tfvars`：复制 `terraform.tfvars.example` 并填写
- 运行预检脚本需 `python3` + `python-hcl2`：`pip install python-hcl2`（CI 已自动安装）

## 快速开始

```bash
cp terraform.tfvars.example terraform.tfvars   # 按需修改
terraform init
terraform plan                                 # 确认变更（check 块会在此阶段报配置错误）
terraform apply
```

或使用 Makefile：`make plan` / `make apply` / `make stage1..4`（`make help` 查看全部）。

首次 `apply` 会依次：开通组织服务 → 创建部门（含嵌套）→ 创建核心/业务账号 → 创建身份并绑定 → 开启 SCP 并绑定 → 配置基线并批量应用。

## 默认账号结构

```
集团根账号（管理账号）
├── 核心账号
│   ├── 安全账号     # 集中部署安全产品
│   ├── 日志账号     # 集中收集审计日志（集中审计日志的归集账号）
│   └── 财务账号     # 财务对账与成本分析
├── 业务部门
│   └── 应用A-生产
└── 沙箱环境
    └── 开发测试
```

## 嵌套部门

`departments` 的元素支持可选 `parent` 字段，指向另一个部门的 key 即创建为子部门，最多 3 层：

```hcl
departments = [
  { key = "core",     name = "Core",     remark = "承载安全、日志、财务等核心账号" },
  { key = "business", name = "Business", remark = "全部业务" },
  { key = "prod",     name = "Prod",     remark = "生产环境", parent = "business" },   # L2
  { key = "proj-x",   name = "ProjectX", remark = "重点项目", parent = "prod" },       # L3
]
```

- 账号的 `department`、防护规则的 `bound_to` 可指向任意层级的部门 key。
- parent 悬空、自引用、循环引用、超过 3 层会在 `terraform plan`（check 块）和预检脚本中同时报错。
- 从旧版本升级：旧的平铺部门均视为 L1，资源地址不变（`org_node.this`），**state 无需迁移**。

## State 管理（远端 backend）

团队协作或 CI 场景务必启用远端 state：

1. 一次性手工创建 COS 桶（建议开启版本控制、默认加密、私有读写）。
2. `cp backend.tf.example backend.tf`，填写桶名 / 路径 / 地域。
3. `terraform init -migrate-state` 将本地 state 迁入 COS。

COS backend 为 Terraform 内置，支持 state locking（详见 [Terraform 文档](https://developer.hashicorp.com/terraform/language/backend/cos)）。

## 集中审计日志（可选）

- 在**日志账号**创建 COS 桶（版本控制 + AES256 加密 + 生命周期保留策略）；
- 在**管理账号**创建组织级云审计跟踪（`track_for_all_members = 1`），全部成员账号的操作日志统一投递到该桶。

**前置条件（一次性手工操作）**：通过登录授权（`OrganizationAdmin` 身份）登录日志账号控制台，在 CAM 创建角色（默认名 `LandingZoneLogArchiveAccess`），信任主体 = 管理账号 UIN，授予 COS 权限（建议 `QcloudCOSFullAccess`）。

然后在 tfvars 中启用：

```hcl
enable_central_logging   = true
audit_log_bucket_name    = "my-org-audit-logs"   # 不含 -APPID 后缀
log_archive_appid        = "1300xxxxxx"
audit_log_retention_days = 365                    # 0 = 永久保留
```

> 若跟踪投递失败，检查日志账号 COS 桶是否已授权云审计服务写入（控制台云审计页面可一键授权）。

## 扩展与裁剪

Landing Zone 设计为数据驱动 + 模块开关，**改 `terraform.tfvars` 即可完成扩展与裁剪，无需改代码**：

| 需求 | 做法 |
|---|---|
| 整体裁剪某个模块 | `enable_guardrails` / `enable_baselines` / `enable_login_permission` / `enable_auditor_policy` / `enable_central_logging` 置 `false` |
| 增删部门 / 嵌套子部门 | 改 `departments`（`parent` 控制层级，最多 3 层） |
| 增删账号 | 改 `core_accounts` / `business_accounts` |
| 增删防护规则（SCP） | 改 `guardrail_policies` map（含绑定目标 `bound_to`） |
| 增删基线项 | 改 `baseline_config_items` 列表 |
| 调整财务权限 / 代付 | 改 `member_permission_ids` / `pay_uin` |
| 启用集中审计日志 | `enable_central_logging = true` + 桶名 / APPID（前置条件见上节） |
| 增删身份（权限集） | 复制/删除 `identities.tf` 中的身份资源块及对应绑定 |

极端裁剪示例（仅组织 + 账号，不启用任何治理模块）：

```hcl
enable_guardrails       = false
enable_baselines        = false
enable_login_permission = false
enable_auditor_policy   = false
# enable_central_logging 默认为 false
```

## 配置校验（三层防线）

配置错误在 apply 之前拦截：

1. **变量 `validation` 块**（`variables.tf`）：加载 tfvars 时即报错——region 格式、部门 key 唯一、财务权限必含 1/2、SCP content 必须是合法 JSON 等。
2. **`check` 块**（`checks.tf`）：`terraform plan` 阶段报错——部门 parent 悬空/循环/超 3 层、账号部门引用、防护规则绑定目标、代付缺 pay_uin、审计日志缺桶名/APPID。
3. **预检脚本**（`scripts/validate-config.py`）：脱离 Terraform 独立校验 tfvars，适合 CI 与快速检查（`make preflight`）。

## 分阶段部署

首次落地建议按依赖顺序分阶段 apply，降低单次变更面、便于逐段验证（`make stage1` … `make stage4` 等价于下表命令）：

| 阶段 | 内容 | 命令 |
|---|---|---|
| 1 组织与账号 | 开通组织、部门（含嵌套）、核心/业务账号 | `terraform apply -target=tencentcloud_organization_instance.this -target=tencentcloud_organization_org_node.this -target=tencentcloud_organization_org_node.level2 -target=tencentcloud_organization_org_node.level3 -target=tencentcloud_organization_org_member.core -target=tencentcloud_organization_org_member.business` |
| 2 身份与防护 | 身份（权限集）、成员策略、登录授权、SCP | `terraform apply -target=tencentcloud_organization_org_identity.* -target=tencentcloud_organization_org_member_policy_attachment.* -target=tencentcloud_organization_org_member_auth_identity_attachment.* -target=tencentcloud_organization_org_manage_policy.*` |
| 3 基线 | 账号工厂基线配置 + 批量应用 | `terraform apply -target=tencentcloud_controlcenter_account_factory_baseline_config.default -target=tencentcloud_batch_apply_account_baselines.all` |
| 4 收尾 | 全量核对（含可选的集中审计日志），补遗漏 | `terraform apply` |

> 每个阶段结束后 `terraform plan` 检查无意外变更再进入下一阶段。账号较多时建议先用 `-target` 试点 1-2 个业务账号验证基线效果，再全量 apply。

## 持续治理

- **CI 校验**：`.github/workflows/terraform-ci.yml` 在 PR / push 时自动执行 `fmt -check`、`validate`、配置预检、checkov 安全扫描（建议性，不阻断）；在仓库 Settings → Secrets 配置 `TENCENTCLOUD_SECRET_ID` / `TENCENTCLOUD_SECRET_KEY` 后，plan 步骤自动启用（不配置则跳过）。
- **漂移检测**：`.github/workflows/drift-detection.yml` 每周一定时执行 `terraform plan -detailed-exitcode`，发现控制台人工操作导致的漂移时 job 失败并触发通知。需配置上述凭证，并将远端 backend（`backend.tf`）纳入版本管理。
- **收敛**：发现 drift 后人工确认，`terraform apply` 收敛回代码定义的状态。

## 默认防护规则（SCP）

| 策略 | 绑定部门 | 说明 |
|---|---|---|
| `DenyOrganizationTampering` | core / business / sandbox | 禁止成员账号退出组织、增删改组织成员与部门结构，组织结构仅允许管理账号变更 |
| `DenyDeleteSecurityResources` | business | 禁止删除 CAM 身份、云审计（含跟踪集）、配置审计、日志与 COS 存储资源 |
| `DenyDeleteCoreNetwork` | business | 禁止删除 VPC、子网、NAT 网关等核心网络资源 |

在 `guardrail_policies` 中增删 map 项即可扩展；`bound_to` 支持任意层级部门。

## 基线项说明

`baselines.tf` 由 `var.baseline_config_items` 驱动，默认包含两个账号工厂基线项（可增删）：

- `TCC-AF_PRESET_TAG`：预设标签基线，给所有账号统一打管理标签
- `TCC-AF_VPC_SUBNET`：VPC/子网基线，为账号创建默认网络

可用基线项及其配置结构可通过控制台或如下 data source 查询：

```hcl
data "tencentcloud_controlcenter_account_factory_baseline_items" "all" {}
```

其他常见基线项：`TCC-AF_SHARE_IMAGE`（共享镜像）、`ACS-BP_ACCOUNT_FACTORY_ACCOUNT_CONTACT`（账号联系人）。

## 注意事项

- **SCP 只定义权限边界，不授予权限**：成员账号的最终权限 = 组织 SCP ∩ 账号内 CAM 权限，仍需在账号内配置 CAM。
- **SCP 启用后默认绑定系统策略 FullQcloudAccess**（全放行），本仓库在此基础上追加 Deny 规则，安全可控。
- **批量接口自动分批**：成员策略绑定与基线批量应用单次上限 10 个 UIN，`locals.tf` 已自动分批，账号超过 10 个无需手工拆分。
- **登录授权**（`org_member_auth_identity_attachment`）单账号最多绑定 5 个身份。
- **删除成员账号**：删除由 Terraform 创建的成员时，如需连带注销腾讯云账号，给资源加 `force_delete_account = true`。
- **邀请已有账号**：邀请型账号需对方同意，请在控制中心完成邀请；本仓库创建的是新账号。
- **代付**：`member_permission_ids` 包含 `7`（代付）时必须设置 `pay_uin`（check 块会在 plan 时拦截）。
- 组织/控制中心为全局服务，`region` 仅用于基线与审计日志等地域性资源。

## 版本要求

- Terraform ≥ 1.5（`check` 块需要）
- tencentcloud provider ≥ 1.82.50（控制中心账号工厂基线资源自 v1.82.44 起提供）

## License

[Apache-2.0](LICENSE)
