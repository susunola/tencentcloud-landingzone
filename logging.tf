# =============================================================================
# Central audit logging
# Maps to the "Compliance Audit" section of the Control Center Landing Zone.
#
# Architecture:
#   1) Log archive account: COS bucket hosting organization-wide audit logs
#      (provider alias + assume_role)
#   2) Management account: organization-wide CloudAudit track
#      (track_for_all_members = 1) delivering operation logs of every member
#      account to the log archive bucket
#
# Prerequisite (one-time manual step):
#   Log in to the log archive account console via login authorization (the
#   OrganizationAdmin identity) and create a CAM role (default name
#   LandingZoneLogArchiveAccess) trusting the management account UIN, with
#   COS write permissions (QcloudCOSFullAccess recommended).
#
# Disabled by default (enable_central_logging = false). Complete the
# prerequisite and set audit_log_bucket_name + log_archive_appid before
# enabling.
# =============================================================================

locals {
  # Log archive account UIN; falls back to an empty string when disabled
  # (the provider alias is never actually configured in that case)
  log_archive_uin = try(tencentcloud_organization_org_member.core[var.log_archive_account_key].id, "")
}

# Log archive account provider: management account credentials + assume_role
# into the pre-created role in the log archive account
provider "tencentcloud" {
  alias      = "log_archive"
  secret_id  = var.tencentcloud_secret_id
  secret_key = var.tencentcloud_secret_key
  region     = var.region

  assume_role {
    role_arn     = "qcs::cam::uin/${local.log_archive_uin}:roleName/${var.log_archive_role_name}"
    session_name = "tf-landingzone-audit"
  }
}

module "audit_logging" {
  source = "./modules/audit-logging"
  count  = var.enable_central_logging ? 1 : 0

  providers = {
    tencentcloud             = tencentcloud
    tencentcloud.log_archive = tencentcloud.log_archive
  }

  bucket_name     = coalesce(var.audit_log_bucket_name, "landingzone-audit-logs")
  appid           = coalesce(var.log_archive_appid, "")
  region          = var.region
  log_archive_uin = local.log_archive_uin
  retention_days  = var.audit_log_retention_days
  track_name      = "org-audit-track"
  storage_prefix  = "cloudaudit"
  tags            = var.tags
}
