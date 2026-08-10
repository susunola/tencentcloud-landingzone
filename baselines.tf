# =============================================================================
# Account factory baselines
# Maps to the "Baseline Management" section of the Control Center Landing Zone:
#   1) Configure baselines: default settings for new/existing accounts
#      (tags, VPC, contacts, etc.)
#   2) Batch apply: apply baselines to selected member accounts
# Extend: add/remove items in var.baseline_config_items
# Trim: set enable_baselines = false
# Supported baseline item identifiers can be listed by adding:
#   data "tencentcloud_controlcenter_account_factory_baseline_items" "all" {}
# =============================================================================

# -----------------------------------------------------------------------------
# Baseline configuration, driven by var.baseline_config_items
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
# Batch-apply baselines to all core and business accounts.
# member_uin_list accepts at most 10 UINs per call; locals.tf chunks the list.
# -----------------------------------------------------------------------------
resource "tencentcloud_batch_apply_account_baselines" "all" {
  count = var.enable_baselines ? length(local.member_uin_chunks) : 0

  member_uin_list = local.member_uin_chunks[count.index]

  dynamic "baseline_config_items" {
    for_each = var.baseline_config_items

    content {
      identifier    = baseline_config_items.value.identifier
      configuration = baseline_config_items.value.configuration
    }
  }
}
