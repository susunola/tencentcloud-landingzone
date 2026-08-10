# tencentcloud-landingzone

基于腾讯云控制中心（Control Center，产品文档 [1220/57785](https://intl.cloud.tencent.com/zh/document/product/1220/57785)）Landing Zone 最佳实践，用 Terraform 将多账号云环境的**组织架构、核心账号、财务、身份权限、防护规则、账号基线**一次性落地，可版本化、可审计、可重复执行。

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
   │ 财务     │   │ 账号      │          │  账号      │   │ 绑定部门  │
   └────┬────┘   └─────┬─────┘          └──────┬─────┘   └──────────┘
        │              │                       │
        └──────┬───────┴───────────┬───────────┘
               │                   │
        ┌──────▼──────┐    ┌───────▼────────┐
        │ 身份与权限    │    │  账号工厂基线    │
        │ 权限集/成员   │    │  标签/VPC/联系人 │
        │ 策略/登录授权 │    │  批量应用到账号   │
        └─────────────┘    └────────────────┘
```

对应控制中心 Landing Zone 的 8 项配置：

| 控制中心配置 | 本仓库实现 | Terraform 资源 |
|---|---|---|
| 部门 | `organization.tf` | `tencentcloud_organization_org_node` |
| 核心账号 | `organization.tf` | `tencentcloud_organization_org_member` |
| 账号创建/邀请 | `organization.tf` | `tencentcloud_organization_org_member` |
| 财务 | `organization.tf` + `variables.tf` | 财务权限 `permission_ids`、代付 `pay_uin` |
| 身份与权限 | `identities.tf` | `org_identity` / `org_member_policy_attachment` / `org_member_auth_identity_attachment` |
| 防护规则 | `guardrails.tf` | `org_manage_policy` + `org_manage_policy_target` |
| 基线管理 | `baselines.tf` | `controlcenter_account_factory_baseline_config` + `batch_apply_account_baselines` |
| 合规审计（日志投递） | 见下方说明 | 日志账号中配置 CloudAudit / Config 投递 |

> 合规审计日志投递（云审计/配置审计日志投递到 COS）需要在日志账号内开通对应服务，可通过控制台或 `tencentcloud_audit` 等资源在日志账号中配置，本仓库在日志账号中预留承载。

## 文件说明

| 文件 | 说明 |
|---|---|
| `main.tf` | Provider 配置、开通组织服务 |
| `organization.tf` | 部门（组织单元）、核心账号、业务/沙箱账号、财务权限 |
| `identities.tf` | 身份（权限集）、成员策略绑定、登录授权 |
| `guardrails.tf` | 防护规则（服务控制策略）创建与绑定 |
| `baselines.tf` | 账号工厂基线配置与批量应用 |
| `variables.tf` / `outputs.tf` | 输入变量与输出 |
| `terraform.tfvars.example` | 变量示例 |

## 前置条件

- 管理账号已完成**企业实名认证**（控制中心仅支持企业账号，个人账号不支持）
- 本地安装 [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.3
- 配置腾讯云 API 凭证（二选一）：
  - 环境变量：`export TENCENTCLOUD_SECRET_ID=... TENCENTCLOUD_SECRET_KEY=...`
  - `terraform.tfvars`：复制 `terraform.tfvars.example` 并填写

## 快速开始

```bash
cp terraform.tfvars.example terraform.tfvars   # 按需修改
terraform init
terraform plan                                 # 确认变更
terraform apply
```

首次 `apply` 会依次：开通组织服务 → 创建部门 → 创建核心/业务账号 → 创建身份并绑定 → 开启 SCP 并绑定 → 配置基线并批量应用。

## 默认账号结构

```
集团根账号（管理账号）
├── 核心账号
│   ├── 安全账号     # 集中部署安全产品
│   ├── 日志账号     # 集中收集审计日志
│   └── 财务账号     # 财务对账与成本分析
├── 业务部门
│   └── 应用A-生产
└── 沙箱环境
    └── 开发测试
```

按需修改 `variables.tf` 中的 `departments` / `core_accounts` / `business_accounts` 即可调整结构。

## 基线项说明

`baselines.tf` 默认配置了两个账号工厂基线项：

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
- **成员策略绑定**（`org_member_policy_attachment`）的 `member_uins` 单次最多 10 个，账号多时请拆分。
- **登录授权**（`org_member_auth_identity_attachment`）单账号最多绑定 5 个身份。
- **删除成员账号**：删除由 Terraform 创建的成员时，如需连带注销腾讯云账号，给资源加 `force_delete_account = true`。
- **邀请已有账号**：邀请型账号需对方同意，请在控制中心完成邀请；本仓库创建的是新账号。
- **代付**：`member_permission_ids` 包含 `7`（代付）时必须设置 `pay_uin`。
- 组织/控制中心为全局服务，`region` 仅用于基线中的地域性资源。

## Provider 版本

控制中心（Control Center）账号工厂基线资源自 tencentcloud provider v1.82.44 提供，`versions.tf` 已要求 `>= 1.82.50`。
