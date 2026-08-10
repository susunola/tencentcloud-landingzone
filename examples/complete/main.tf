# Complete Landing Zone: every module enabled, with nested departments and
# central audit logging.

module "landingzone" {
  source = "../.."

  region         = "ap-guangzhou"
  root_node_name = "Root"

  # Nested departments: root -> business -> prod -> proj-x (3 levels max)
  departments = [
    { key = "core", name = "Core", remark = "Hosts security, logging and finance core accounts" },
    { key = "business", name = "Business", remark = "All business accounts" },
    { key = "prod", name = "Prod", remark = "Production", parent = "business" },
    { key = "proj-x", name = "ProjectX", remark = "Key project", parent = "prod" },
    { key = "sandbox", name = "Sandbox", remark = "Test and experiment accounts" },
  ]

  business_accounts = {
    "app-prod" = {
      name       = "AppA-Production"
      remark     = "Production business account"
      department = "prod"
    }
    "dev-test" = {
      name       = "DevTest"
      remark     = "Sandbox test account"
      department = "sandbox"
    }
  }

  # All governance modules enabled (these are the defaults; listed for clarity)
  enable_guardrails       = true
  enable_baselines        = true
  enable_login_permission = true
  enable_auditor_policy   = true

  # Central audit logging — complete the one-time prerequisite first
  # (see README.md in this directory). Replace the placeholder APPID.
  enable_central_logging   = true
  audit_log_bucket_name    = "example-org-audit-logs"
  log_archive_appid        = "1300000000"
  audit_log_retention_days = 365
}

output "organization_id" {
  value = module.landingzone.organization_id
}

output "department_nodes" {
  value = module.landingzone.department_nodes
}

output "audit_log_bucket" {
  value = module.landingzone.audit_log_bucket
}
