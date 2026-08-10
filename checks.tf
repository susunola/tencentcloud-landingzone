# =============================================================================
# Configuration reference consistency checks (Terraform >= 1.5 check blocks;
# violations fail at plan time).
# Complementary to scripts/validate-config.py: check blocks run automatically
# on every plan/apply, while the preflight script provides Terraform-free
# quick validation for local runs and CI.
# =============================================================================

# Department parent references must resolve (dangling parents, cycles and
# nesting deeper than 3 levels all land in the unresolved set)
check "department_nesting_resolvable" {
  assert {
    condition     = length([for d in var.departments : d.key if contains(local.unresolved_department_keys, d.key)]) == 0
    error_message = "Unresolvable department parents (dangling reference, cycle, or nesting deeper than 3 levels): ${join(", ", local.unresolved_department_keys)}"
  }
}

# Account department references must exist
check "account_department_references" {
  assert {
    condition = alltrue(concat(
      [for a in var.core_accounts : contains(keys(local.departments_by_key), a.department)],
      [for k, a in var.business_accounts : contains(keys(local.departments_by_key), a.department)],
    ))
    error_message = "core_accounts / business_accounts reference a department key that does not exist in departments"
  }
}

# Guardrail attachment targets must exist
check "guardrail_binding_targets" {
  assert {
    condition = alltrue(flatten([
      for name, p in var.guardrail_policies :
      [for t in p.bound_to : contains(keys(local.departments_by_key), t)]
    ]))
    error_message = "guardrail_policies bound_to references a department key that does not exist in departments"
  }
}

# Finance: pay_uin is required when delegated payment (7) is enabled
check "pay_uin_required_for_delegated_pay" {
  assert {
    condition     = !contains(var.member_permission_ids, 7) || var.pay_uin != null
    error_message = "pay_uin must be set when member_permission_ids includes 7 (delegated payment)"
  }
}

# Central audit logging: bucket name and APPID are required when enabled
check "central_logging_prerequisites" {
  assert {
    condition     = !var.enable_central_logging || (var.audit_log_bucket_name != null && var.log_archive_appid != null)
    error_message = "audit_log_bucket_name and log_archive_appid must be set when enable_central_logging = true"
  }
}
