output "organization_id" {
  description = "集团账号管理（组织）ID"
  value       = tencentcloud_organization_instance.this.org_id
}

output "root_node_id" {
  description = "组织根节点 ID"
  value       = tencentcloud_organization_instance.this.root_node_id
}

output "department_nodes" {
  description = "部门（组织单元）ID，key 对应 departments 中的 key"
  value = {
    for k, n in tencentcloud_organization_org_node.this : k => n.id
  }
}

output "core_account_uins" {
  description = "核心账号 UIN，key 对应 core_accounts 中的 key"
  value = {
    for k, m in tencentcloud_organization_org_member.core : k => m.id
  }
}

output "business_account_uins" {
  description = "业务/沙箱账号 UIN"
  value = {
    for k, m in tencentcloud_organization_org_member.business : k => m.id
  }
}

output "identity_ids" {
  description = "自定义身份（权限集）ID"
  value = {
    admin_login  = tencentcloud_organization_org_identity.admin_login.id
    security_ops = tencentcloud_organization_org_identity.security_ops.id
    auditor      = tencentcloud_organization_org_identity.auditor.id
  }
}

output "baseline_id" {
  description = "账号工厂基线配置 ID"
  value       = tencentcloud_controlcenter_account_factory_baseline_config.default.id
}
