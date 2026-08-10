output "organization_id" {
  description = "Organization (group account management) ID"
  value       = tencentcloud_organization_instance.this.org_id
}

output "root_node_id" {
  description = "Organization root node ID"
  value       = tencentcloud_organization_instance.this.root_node_id
}

output "department_nodes" {
  description = "Department (organizational unit) IDs, keyed by departments key (including nested sub-departments)"
  value       = local.department_node_ids
}

output "core_account_uins" {
  description = "Core account UINs, keyed by core_accounts key"
  value = {
    for k, m in tencentcloud_organization_org_member.core : k => m.id
  }
}

output "business_account_uins" {
  description = "Business/sandbox account UINs"
  value = {
    for k, m in tencentcloud_organization_org_member.business : k => m.id
  }
}

output "identity_ids" {
  description = "Custom identity (permission set) IDs"
  value = {
    admin_login  = tencentcloud_organization_org_identity.admin_login.id
    security_ops = tencentcloud_organization_org_identity.security_ops.id
    auditor      = tencentcloud_organization_org_identity.auditor.id
  }
}

output "manage_policy_ids" {
  description = "Guardrail (SCP) policy IDs, keyed by guardrail_policies policy name"
  value = {
    for k, p in tencentcloud_organization_org_manage_policy.this : k => p.policy_id
  }
}

output "baseline_id" {
  description = "Account factory baseline configuration ID (null when enable_baselines = false)"
  value       = try(tencentcloud_controlcenter_account_factory_baseline_config.default[0].id, null)
}

output "audit_log_bucket" {
  description = "Central audit log COS bucket, full name with -APPID suffix (null when enable_central_logging = false)"
  value       = try(module.audit_logging[0].bucket_name, null)
}
