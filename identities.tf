# =============================================================================
# Identities & permissions (permission sets)
# Maps to the "Identities & Permissions" section of the Control Center
# Landing Zone:
#   1) Identities (permission sets): preset or custom policy collections
#   2) Member policies: bind identities to member accounts
#   3) Login authorization: management account logs in to member accounts
#      with a given identity (unified member access)
# =============================================================================

# -----------------------------------------------------------------------------
# Identity 1: organization admin login identity (preset AdministratorAccess,
# CAM preset policy ID = 1)
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_identity" "admin_login" {
  identity_alias_name = "OrganizationAdmin"
  description         = "Used by organization admins to log in to member accounts; preset AdministratorAccess"

  identity_policy {
    policy_type = 2 # 2 = preset policy
    policy_id   = 1 # CAM preset policy ID, 1 = AdministratorAccess
    policy_name = "AdministratorAccess"
  }
}

# -----------------------------------------------------------------------------
# Identity 2: security operations (custom policy)
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_identity" "security_ops" {
  identity_alias_name = "SecurityOps"
  description         = "Security account operations identity: security products + log read access"

  identity_policy {
    policy_type = 1 # 1 = custom policy

    # Read/write on the security products (waf, yunjing, ssl). Compute and
    # network are restricted to Describe* so this identity can inspect but not
    # tear down VMs/VPCs — otherwise it would contradict the DenyDeleteCoreNetwork
    # SCP and give a security identity broad delete rights if copied to an
    # account without that SCP.
    policy_document = jsonencode({
      version = "2.0"
      statement = [
        {
          effect = "allow"
          action = [
            "waf:*",
            "yunjing:*",
            "ssl:*",
            "cls:Describe*",
            "cvm:Describe*",
            "vpc:Describe*",
          ]
          resource = ["*"]
        }
      ]
    })
  }
}

# -----------------------------------------------------------------------------
# Identity 3: read-only auditor (custom policy, avoids depending on preset
# policy IDs)
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_identity" "auditor" {
  identity_alias_name = "Auditor"
  description         = "Organization-wide read-only audit identity"

  identity_policy {
    policy_type = 1

    policy_document = jsonencode({
      version = "2.0"
      statement = [
        {
          effect = "allow"
          action = [
            "cvm:Describe*",
            "vpc:Describe*",
            "cos:Get*",
            "cls:Describe*",
            "monitor:Describe*",
            "cloudaudit:Describe*",
            "config:Describe*",
            "cam:Get*",
            "cam:List*",
          ]
          resource = ["*"]
        }
      ]
    })
  }
}

# -----------------------------------------------------------------------------
# Member policy: bind the SecurityOps identity to the security account
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_member_policy_attachment" "security_ops" {
  member_uins = [tencentcloud_organization_org_member.core["security"].id]
  policy_name = "SecurityOpsPolicy"
  identity_id = tencentcloud_organization_org_identity.security_ops.id
  description = "Security operations policy for the security account"
}

# -----------------------------------------------------------------------------
# Member policy: bind the read-only auditor identity to all accounts.
# member_uins accepts at most 10 UINs per call; locals.tf chunks the list so
# larger account sets automatically produce multiple instances.
# (count is kept on purpose: the auditor[0] address matches the first chunk,
# so states created by older versions need no migration.)
# Trim: set enable_auditor_policy = false
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_member_policy_attachment" "auditor" {
  count = var.enable_auditor_policy ? length(local.member_uin_chunks) : 0

  member_uins = local.member_uin_chunks[count.index]
  policy_name = count.index == 0 ? "AuditorPolicy" : "AuditorPolicy-${count.index + 1}"
  identity_id = tencentcloud_organization_org_identity.auditor.id
  description = "Organization-wide read-only audit policy"
}

# -----------------------------------------------------------------------------
# Login authorization: management account logs in to business accounts with
# the OrganizationAdmin identity.
# Trim: set enable_login_permission = false
# To also authorize login to core accounts, switch for_each to the union of
# core and business members.
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_member_auth_identity_attachment" "admin_login" {
  for_each = var.enable_login_permission ? tencentcloud_organization_org_member.business : {}

  member_uin   = each.value.id
  identity_ids = [tencentcloud_organization_org_identity.admin_login.id]
}
