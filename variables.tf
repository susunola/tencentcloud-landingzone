# =============================================================================
# 通用
# =============================================================================
variable "tencentcloud_secret_id" {
  description = "腾讯云 API 密钥 SecretId，留空则使用环境变量 TENCENTCLOUD_SECRET_ID"
  type        = string
  default     = null
  sensitive   = true
}

variable "tencentcloud_secret_key" {
  description = "腾讯云 API 密钥 SecretKey，留空则使用环境变量 TENCENTCLOUD_SECRET_KEY"
  type        = string
  default     = null
  sensitive   = true
}

variable "region" {
  description = "腾讯云地域，组织/控制中心为全局服务，此参数用于创建地域性资源（如基线 VPC）"
  type        = string
  default     = "ap-guangzhou"
}

variable "root_node_name" {
  description = "组织根节点名称（管理账号下的根部门）"
  type        = string
  default     = "集团根账号"
}

variable "tags" {
  description = "全局标签，附加到可打标签的资源上"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "LandingZone"
  }
}

# =============================================================================
# 模块开关（裁剪用）：置 false 即整体跳过对应模块
# =============================================================================
variable "enable_guardrails" {
  description = "是否创建并绑定防护规则（服务控制策略 SCP），false 则整个防护规则模块不生效"
  type        = bool
  default     = true
}

variable "enable_baselines" {
  description = "是否配置并批量应用账号工厂基线，false 则整个基线模块不生效"
  type        = bool
  default     = true
}

variable "enable_login_permission" {
  description = "是否开启管理账号以管理员身份登录业务账号（登录授权）"
  type        = bool
  default     = true
}

variable "enable_auditor_policy" {
  description = "是否将只读审计身份绑定到全部账号"
  type        = bool
  default     = true
}

# =============================================================================
# 部门（组织单元）与账号
# =============================================================================
variable "departments" {
  description = <<-EOT
    部门（组织单元）列表，key 用作资源标识，name 为部门显示名称。
    对应控制中心 Landing Zone 的「部门」配置。
  EOT
  type = list(object({
    key    = string
    name   = string
    remark = string
  }))
  default = [
    { key = "core", name = "核心账号", remark = "承载安全、日志、财务等核心账号" },
    { key = "business", name = "业务部门", remark = "生产业务账号" },
    { key = "sandbox", name = "沙箱环境", remark = "测试与实验账号，禁止承载生产业务" },
  ]
}

variable "core_accounts" {
  description = <<-EOT
    核心账号（由管理账号代管的关键账号），对应控制中心 Landing Zone 的「核心账号」配置。
    每个元素：key（资源标识）、name、department（必须是 departments 中的 key）、remark。
  EOT
  type = list(object({
    key        = string
    name       = string
    department = string
    remark     = string
  }))
  default = [
    { key = "security", name = "安全账号", department = "core", remark = "集中部署安全产品（WAF、主机安全等）" },
    { key = "logging", name = "日志账号", department = "core", remark = "集中收集操作审计、配置审计日志" },
    { key = "finance", name = "财务账号", department = "core", remark = "财务对账与成本分析" },
  ]
}

variable "business_accounts" {
  description = <<-EOT
    业务/沙箱账号，key 为资源标识，department 必须是 departments 中的 key。
    对应控制中心 Landing Zone 的「账号邀请/创建」配置。
  EOT
  type = map(object({
    name       = string
    remark     = string
    department = string
  }))
  default = {
    "app-prod" = {
      name       = "应用A-生产"
      remark     = "生产环境业务账号"
      department = "business"
    }
    "dev-test" = {
      name       = "开发测试"
      remark     = "沙箱测试账号"
      department = "sandbox"
    }
  }
}

# =============================================================================
# 财务
# =============================================================================
variable "member_permission_ids" {
  description = <<-EOT
    成员财务权限（对应 Landing Zone「财务」配置）：
    1 查账单、2 查余额、3 资金划拨、4 合并账单、5 开发票、6 继承优惠、7 代付
    必含 1、2；包含 7 时必须设置 pay_uin
  EOT
  type        = list(number)
  default     = [1, 2, 4]
}

variable "pay_uin" {
  description = "代付账号 UIN，仅当 member_permission_ids 包含 7 时需要"
  type        = string
  default     = null
}

# =============================================================================
# 防护规则（服务控制策略，可扩展：增删 map 项即可；裁剪：清空 map 或关开关）
# =============================================================================
variable "guardrail_policies" {
  description = <<-EOT
    防护规则（SCP）map，key 为策略名，bound_to 为要绑定的部门 key 列表
    （必须是 departments 中的 key）。content 为 CAM 策略语法 JSON。
  EOT
  type = map(object({
    description = string
    content     = string
    bound_to    = list(string)
  }))
  default = {
    DenyDeleteSecurityResources = {
      description = "禁止删除 CAM 身份、审计、日志与存储资源，保护安全合规资产"
      bound_to    = ["business"]
      content     = <<-EOT
      {
        "version": "2.0",
        "statement": [
          {
            "effect": "deny",
            "action": [
              "cam:DeleteUser",
              "cam:DeleteRole",
              "cam:DeletePolicy",
              "cloudaudit:DeleteAudit",
              "cloudaudit:StopLogging",
              "config:DeleteConfigRule",
              "cls:DeleteLogset",
              "cls:DeleteTopic",
              "cos:DeleteBucket"
            ],
            "resource": ["*"]
          }
        ]
      }
      EOT
    }
    DenyDeleteCoreNetwork = {
      description = "禁止删除 VPC、子网、NAT 网关等核心网络资源"
      bound_to    = ["business"]
      content     = <<-EOT
      {
        "version": "2.0",
        "statement": [
          {
            "effect": "deny",
            "action": [
              "vpc:DeleteVpc",
              "vpc:DeleteSubnet",
              "vpc:DeleteNatGateway",
              "vpc:DeleteVpnGateway"
            ],
            "resource": ["*"]
          }
        ]
      }
      EOT
    }
  }
}

# =============================================================================
# 账号工厂基线（可扩展：增删列表项即可；裁剪：清空列表或关开关）
# =============================================================================
variable "baseline_name" {
  description = "账号工厂基线名称，须唯一"
  type        = string
  default     = "default"
}

variable "baseline_config_items" {
  description = <<-EOT
    账号工厂基线项列表（identifier + configuration JSON），按需增删。
    identifier 可通过 data source tencentcloud_controlcenter_account_factory_baseline_items 查询。
  EOT
  type = list(object({
    identifier    = string
    configuration = string
  }))
  default = [
    {
      identifier    = "TCC-AF_PRESET_TAG"
      configuration = <<-EOT
      {
        "TagValuePairs": [
          { "Key": "Environment", "Values": ["managed"] }
        ]
      }
      EOT
    },
    {
      identifier    = "TCC-AF_VPC_SUBNET"
      configuration = <<-EOT
      {
        "VpcName": "default-vpc",
        "CidrBlock": "10.0.0.0/16",
        "Region": 1,
        "RegionName": "ap-guangzhou",
        "Subnets": [
          { "CidrBlock": "10.0.1.0/24", "SubnetName": "app", "Zone": "ap-guangzhou-6" },
          { "CidrBlock": "10.0.2.0/24", "SubnetName": "db",  "Zone": "ap-guangzhou-6" }
        ]
      }
      EOT
    },
  ]
}
