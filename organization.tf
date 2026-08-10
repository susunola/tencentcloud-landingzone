# =============================================================================
# 部门（组织单元）
# 对应控制中心 Landing Zone「部门」配置
# =============================================================================
resource "tencentcloud_organization_org_node" "this" {
  for_each = { for d in var.departments : d.key => d }

  name           = each.value.name
  parent_node_id = tencentcloud_organization_instance.this.root_node_id
  remark         = each.value.remark
}

# =============================================================================
# 核心账号（安全 / 日志 / 财务）
# 对应控制中心 Landing Zone「核心账号」配置
# 注意：删除时如需连带删除腾讯云账号本身，请设置 force_delete_account = true
# =============================================================================
resource "tencentcloud_organization_org_member" "core" {
  for_each = { for c in var.core_accounts : c.key => c }

  name           = each.value.name
  node_id        = tencentcloud_organization_org_node.this[each.value.department].id
  policy_type    = "Financial"
  permission_ids = var.member_permission_ids
  pay_uin        = contains(var.member_permission_ids, 7) ? var.pay_uin : null
  remark         = each.value.remark
  tags           = var.tags
}

# =============================================================================
# 业务 / 沙箱账号
# 对应控制中心 Landing Zone「账号创建 / 邀请」配置（此处为创建型账号）
# =============================================================================
resource "tencentcloud_organization_org_member" "business" {
  for_each = var.business_accounts

  name           = each.value.name
  node_id        = tencentcloud_organization_org_node.this[each.value.department].id
  policy_type    = "Financial"
  permission_ids = var.member_permission_ids
  pay_uin        = contains(var.member_permission_ids, 7) ? var.pay_uin : null
  remark         = each.value.remark
  tags           = var.tags
}
