# =============================================================================
# 账号工厂基线（Account Factory Baseline）
# 对应控制中心 Landing Zone「基线管理」配置：
#   1) 配置基线：定义新账号/存量账号的默认配置（标签、VPC、联系人等）
#   2) 批量应用：将基线应用到指定成员账号
# 支持的基线项 identifier 可通过 data source 查询：
#   data "tencentcloud_controlcenter_account_factory_baseline_items" "all" {}
# =============================================================================

# 查询账号工厂支持的基线项（identifier、分类、必填项等）
data "tencentcloud_controlcenter_account_factory_baseline_items" "all" {}

# -----------------------------------------------------------------------------
# 基线配置：预设标签 + VPC/子网
# -----------------------------------------------------------------------------
resource "tencentcloud_controlcenter_account_factory_baseline_config" "default" {
  name = var.baseline_name

  # 预设标签基线：所有账号统一打上管理标签
  baseline_config_items {
    identifier = "TCC-AF_PRESET_TAG"

    configuration = jsonencode({
      TagValuePairs = [
        { Key = var.default_tag_key, Values = [var.default_tag_value] }
      ]
    })
  }

  # VPC/子网基线：为账号创建默认 VPC 与子网
  baseline_config_items {
    identifier = "TCC-AF_VPC_SUBNET"

    configuration = jsonencode({
      VpcName    = "default-vpc"
      CidrBlock  = var.baseline_vpc_cidr
      Region     = 1 # 地域编码，1=广州；其他地域请按基线项定义调整
      RegionName = var.region
      Subnets = [
        { CidrBlock = cidrsubnet(var.baseline_vpc_cidr, 8, 1), SubnetName = "app", Zone = var.baseline_zone },
        { CidrBlock = cidrsubnet(var.baseline_vpc_cidr, 8, 2), SubnetName = "db", Zone = var.baseline_zone },
      ]
    })
  }
}

# -----------------------------------------------------------------------------
# 将基线批量应用到全部核心账号与业务账号
# -----------------------------------------------------------------------------
resource "tencentcloud_batch_apply_account_baselines" "all" {
  member_uin_list = concat(
    [for m in tencentcloud_organization_org_member.core : m.id],
    [for m in tencentcloud_organization_org_member.business : m.id],
  )

  baseline_config_items {
    identifier = "TCC-AF_PRESET_TAG"

    configuration = jsonencode({
      TagValuePairs = [
        { Key = var.default_tag_key, Values = [var.default_tag_value] }
      ]
    })
  }
}
