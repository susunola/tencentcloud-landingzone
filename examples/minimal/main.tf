# Minimal Landing Zone: organization, departments and accounts only.

# Every governance module is disabled via feature flags.
module "landingzone" {
  source = "../.."

  region         = "ap-guangzhou"
  root_node_name = "Root"

  enable_guardrails       = false
  enable_baselines        = false
  enable_login_permission = false
  enable_auditor_policy   = false
}

output "organization_id" {
  value = module.landingzone.organization_id
}

output "department_nodes" {
  value = module.landingzone.department_nodes
}
