# =============================================================================
# Provider 配置
# 凭证优先级：terraform.tfvars 变量 > 环境变量 TENCENTCLOUD_SECRET_ID /
# TENCENTCLOUD_SECRET_KEY > 共享凭证文件 ~/.tccli/credentials
# 组织/控制中心为全局服务，region 仅用于创建地域性资源（如基线中的 VPC）
# =============================================================================
provider "tencentcloud" {
  secret_id  = var.tencentcloud_secret_id
  secret_key = var.tencentcloud_secret_key
  region     = var.region
}

# -----------------------------------------------------------------------------
# 开通集团账号管理（组织）服务
# 这是整个 Landing Zone 的起点，等价于控制中心「配置 Landing Zone」前的组织开通
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_instance" "this" {
  root_node_name = var.root_node_name
}
