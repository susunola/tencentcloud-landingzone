# =============================================================================
# 防护规则（服务控制策略 SCP）
# 对应控制中心 Landing Zone「防护规则」配置
# SCP 只定义权限边界，不授予权限；绑定到部门后对部门及其下所有账号生效
# 可扩展：在 var.guardrail_policies 中增删策略与绑定目标
# 可裁剪：enable_guardrails = false 整体关闭
# =============================================================================

# 开启集团策略（服务控制策略）能力
resource "tencentcloud_organization_org_manage_policy_config" "scp" {
  count = var.enable_guardrails ? 1 : 0

  organization_id = tencentcloud_organization_instance.this.org_id
  policy_type     = "SERVICE_CONTROL_POLICY"
}

# 防护规则（SCP），由 var.guardrail_policies 驱动
resource "tencentcloud_organization_org_manage_policy" "this" {
  for_each = var.enable_guardrails ? var.guardrail_policies : {}

  name        = each.key
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.content
}

# 策略 × 部门 绑定关系推导
locals {
  guardrail_bindings = var.enable_guardrails ? flatten([
    for name, p in var.guardrail_policies : [
      for t in p.bound_to : { policy = name, target = t }
    ]
  ]) : []
}

# 将防护规则绑定到指定部门（对部门及其下账号生效）
resource "tencentcloud_organization_org_manage_policy_target" "this" {
  for_each = { for b in local.guardrail_bindings : "${b.policy}:${b.target}" => b }

  target_id   = tencentcloud_organization_org_node.this[each.value.target].id
  target_type = "NODE"
  policy_id   = tencentcloud_organization_org_manage_policy.this[each.value.policy].policy_id
  policy_type = "SERVICE_CONTROL_POLICY"
}
