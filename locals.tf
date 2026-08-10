# =============================================================================
# Shared locals: member account set and chunking.
# Both member policy attachment (org_member_policy_attachment) and baseline
# batch application (batch_apply_account_baselines) accept at most 10 UINs per
# call, so chunking is done once here and shared.
# =============================================================================

locals {
  # All member account UINs (core + business/sandbox)
  all_member_uins = concat(
    [for m in tencentcloud_organization_org_member.core : m.id],
    [for m in tencentcloud_organization_org_member.business : m.id],
  )

  # Chunk into batches of 10; more than 10 accounts automatically produce
  # multiple resource instances
  member_uin_chunks = chunklist(local.all_member_uins, 10)
}
