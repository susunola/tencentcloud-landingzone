# =============================================================================
# 账号工厂基线（Account Factory Baseline）
# 对应控制中心 Landing Zone「基线管理」配置：
#   1) 配置基线：定义新账号/存量账号的默认配置（标签、VPC、联系人等）
#   2) 批量应用：将基线应用到指定成员账号
# 可扩展：在 var.baseline_config_items 中增删基线项
# 可裁剪：enable_baselines = false 整体关闭
# 支持的基线项 identifier 可通过 data source 查询：
#   data "tencentcloud_controlcenter_account_factory_baseline_items" "all" {}
# =============================================================================

# 查询账号工厂支持的基线项（identifier、分类、必填项等）
data "tencentcloud_controlcenter_account_factory_baseline_items" "all" {}

# -----------------------------------------------------------------------------
# 基线配置，由 var.baseline_config_items 驱动
# -----------------------------------------------------------------------------
resource "tencentcloud_controlcenter_account_factory_baseline_config" "default" {
  count = var.enable_baselines ? 1 : 0

  name = var.baseline_name

  dynamic "baseline_config_items" {
    for_each = var.baseline_config_items

    content {
      identifier    = baseline_config_items.value.identifier
      configuration = baseline_config_items.value.configuration
    }
  }
}

# -----------------------------------------------------------------------------
# 将基线批量应用到全部核心账号与业务账号
# -----------------------------------------------------------------------------
resource "tencentcloud_batch_apply_account_baselines" "all" {
  count = var.enable_baselines ? 1 : 0

  member_uin_list = concat(
    [for m in tencentcloud_organization_org_member.core : m.id],
    [for m in tencentcloud_organization_org_member.business : m.id],
  )

  dynamic "baseline_config_items" {
    for_each = var.baseline_config_items

    content {
      identifier    = baseline_config_items.value.identifier
      configuration = baseline_config_items.value.configuration
    }
  }
}
