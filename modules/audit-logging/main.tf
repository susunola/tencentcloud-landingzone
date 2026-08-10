# =============================================================================
# Central audit logging
#   - COS bucket (log archive account): versioning + server-side encryption +
#     retention lifecycle
#   - CloudAudit track (management account): track_for_all_members = 1,
#     delivering logs of all member accounts to the bucket
# =============================================================================

resource "tencentcloud_cos_bucket" "audit" {
  provider = tencentcloud.log_archive

  bucket               = "${var.bucket_name}-${var.appid}"
  acl                  = "private"
  versioning_enable    = true
  encryption_algorithm = "AES256"
  force_clean          = false # never let terraform destroy wipe a bucket holding audit logs
  tags                 = var.tags

  dynamic "lifecycle_rules" {
    for_each = var.retention_days > 0 ? [var.retention_days] : []

    content {
      id            = "expire-audit-logs"
      filter_prefix = "${var.storage_prefix}/"
      expiration {
        days = lifecycle_rules.value
      }
    }
  }
}

resource "tencentcloud_audit_track" "org" {
  # default provider (management account)
  name                  = var.track_name
  action_type           = "*"   # all read/write APIs
  event_names           = ["*"] # all events
  resource_type         = "*"   # all products
  status                = 1     # enabled
  track_for_all_members = 1     # organization-wide: covers all member accounts

  storage {
    storage_type       = "cos"
    storage_name       = var.bucket_name # without the -APPID suffix
    storage_prefix     = var.storage_prefix
    storage_region     = var.region
    storage_account_id = var.log_archive_uin
    storage_app_id     = var.appid
  }

  depends_on = [tencentcloud_cos_bucket.audit]
}
