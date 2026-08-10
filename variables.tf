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
# 账号工厂基线（对应 Landing Zone「基线管理」配置）
# =============================================================================
variable "baseline_name" {
  description = "账号工厂基线名称，须唯一"
  type        = string
  default     = "default"
}

variable "default_tag_key" {
  description = "预设标签基线的 Tag Key"
  type        = string
  default     = "Environment"
}

variable "default_tag_value" {
  description = "预设标签基线的 Tag Value"
  type        = string
  default     = "managed"
}

variable "baseline_vpc_cidr" {
  description = "VPC/子网基线的 VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "baseline_zone" {
  description = "VPC/子网基线创建子网的可用区"
  type        = string
  default     = "ap-guangzhou-6"
}
