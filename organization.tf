# =============================================================================
# Departments (organizational units), with nesting support.
# Maps to the "Departments" section of the Control Center Landing Zone.
#
# Level resolution: up to 3 levels (organization root -> L1 -> L2 -> L3).
#   - parent = null (default) -> L1, attached to the organization root
#   - parent -> L1 department key -> L2
#   - parent -> L2 department key -> L3
# Deeper nesting, dangling parents or cycles are reported by the check blocks
# in checks.tf.
#
# Note: the L1 resource keeps its original name "this", so existing states
# (flat departments only) require no migration.
# =============================================================================

locals {
  departments_by_key = { for d in var.departments : d.key => d }

  dept_level1 = { for k, d in local.departments_by_key : k => d if d.parent == null }
  # Note: HCL && does not short-circuit function arguments, and coalesce
  # rejects empty strings, so normalize null parents via a ternary first
  dept_level2 = { for k, d in local.departments_by_key : k => d if contains(keys(local.dept_level1), d.parent == null ? "" : d.parent) }
  dept_level3 = { for k, d in local.departments_by_key : k => d if contains(keys(local.dept_level2), d.parent == null ? "" : d.parent) }

  # Department keys that could not be resolved within 3 levels (dangling
  # parent / cycle / too deep); reported by checks.tf
  unresolved_department_keys = [
    for k in keys(local.departments_by_key) : k
    if !contains(keys(local.dept_level1), k) && !contains(keys(local.dept_level2), k) && !contains(keys(local.dept_level3), k)
  ]

  # All department keys -> node IDs; the single reference point for account
  # placement, guardrail attachment and outputs
  department_node_ids = merge(
    { for k, n in tencentcloud_organization_org_node.this : k => n.id },
    { for k, n in tencentcloud_organization_org_node.level2 : k => n.id },
    { for k, n in tencentcloud_organization_org_node.level3 : k => n.id },
  )
}

# L1: departments directly under the organization root
resource "tencentcloud_organization_org_node" "this" {
  for_each = local.dept_level1

  name           = each.value.name
  parent_node_id = tencentcloud_organization_instance.this.root_node_id
  remark         = each.value.remark
}

# L2: parent points to an L1 department
resource "tencentcloud_organization_org_node" "level2" {
  for_each = local.dept_level2

  name           = each.value.name
  parent_node_id = tencentcloud_organization_org_node.this[each.value.parent].id
  remark         = each.value.remark
}

# L3: parent points to an L2 department
resource "tencentcloud_organization_org_node" "level3" {
  for_each = local.dept_level3

  name           = each.value.name
  parent_node_id = tencentcloud_organization_org_node.level2[each.value.parent].id
  remark         = each.value.remark
}

# =============================================================================
# Core accounts (Security / Logging / Finance)
# Maps to the "Core Accounts" section of the Control Center Landing Zone.
# Note: to also deregister the Tencent Cloud account itself on destroy,
# set force_delete_account = true.
# =============================================================================
resource "tencentcloud_organization_org_member" "core" {
  for_each = { for c in var.core_accounts : c.key => c }

  name           = each.value.name
  node_id        = local.department_node_ids[each.value.department]
  policy_type    = "Financial"
  permission_ids = var.member_permission_ids
  pay_uin        = contains(var.member_permission_ids, 7) ? var.pay_uin : null
  remark         = each.value.remark
  tags           = local.common_tags
}

# =============================================================================
# Business / sandbox accounts
# Maps to the "Account Creation / Invitation" section of the Control Center
# Landing Zone (this repo creates new accounts).
# =============================================================================
resource "tencentcloud_organization_org_member" "business" {
  for_each = var.business_accounts

  name           = each.value.name
  node_id        = local.department_node_ids[each.value.department]
  policy_type    = "Financial"
  permission_ids = var.member_permission_ids
  pay_uin        = contains(var.member_permission_ids, 7) ? var.pay_uin : null
  remark         = each.value.remark
  tags           = local.common_tags
}
