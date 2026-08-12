# =============================================================================
# Post-deploy runtime assertions (Terraform >= 1.5 check blocks).
#
# IMPORTANT: a failed `check` block is reported as a WARNING ONLY and does NOT
# block plan/apply ("the check block is the only validation that does not block
# operations"). It is therefore the wrong place for pre-apply config
# validation. The config-consistency rules that used to live here (department
# nesting, account/guardrail references, pay_uin, central-logging prerequisites)
# are now variable `validation` blocks in variables.tf, which hard-fail at plan
# time and cannot be silently skipped.
#
# check blocks are kept for what they are actually good at: post-apply health /
# compliance signals. They run after the resources are created and surface
# drift or unexpected state without stopping the operation. Extend with
# post-deploy assertions (e.g. verify an SCP actually denies what it should)
# as described in ROADMAP.md ("E2E compliance assertions").
# =============================================================================

# The organization must be enabled and expose a root node id.
check "organization_enabled" {
  assert {
    condition     = tencentcloud_organization_instance.this.root_node_id != ""
    error_message = "Organization was not enabled: the root node id is empty, so the rest of the Landing Zone has nothing to attach to"
  }
}
