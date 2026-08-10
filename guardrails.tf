# =============================================================================
# Guardrails (Service Control Policies)
# Maps to the "Guardrails" section of the Control Center Landing Zone.
# SCPs only define permission boundaries; they never grant permissions.
# Once attached to a department, an SCP applies to the department and all
# accounts under it.
# Extend: add/remove entries in var.guardrail_policies
# Trim: set enable_guardrails = false
# =============================================================================

# Enable the organization policy (Service Control Policy) capability
resource "tencentcloud_organization_org_manage_policy_config" "scp" {
  count = var.enable_guardrails ? 1 : 0

  organization_id = tencentcloud_organization_instance.this.org_id
  policy_type     = "SERVICE_CONTROL_POLICY"
}

# Guardrails (SCPs), driven by var.guardrail_policies
resource "tencentcloud_organization_org_manage_policy" "this" {
  for_each = var.enable_guardrails ? var.guardrail_policies : {}

  name        = each.key
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.content
}

# Derived policy x department attachment pairs
locals {
  guardrail_bindings = var.enable_guardrails ? flatten([
    for name, p in var.guardrail_policies : [
      for t in p.bound_to : { policy = name, target = t }
    ]
  ]) : []
}

# Attach guardrails to departments (applies to the department and all accounts
# under it; nested departments at any level are supported)
resource "tencentcloud_organization_org_manage_policy_target" "this" {
  for_each = { for b in local.guardrail_bindings : "${b.policy}:${b.target}" => b }

  target_id   = local.department_node_ids[each.value.target]
  target_type = "NODE"
  policy_id   = tencentcloud_organization_org_manage_policy.this[each.value.policy].policy_id
  policy_type = "SERVICE_CONTROL_POLICY"
}
