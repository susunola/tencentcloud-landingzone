output "bucket_name" {
  description = "Audit log COS bucket, full name with the -APPID suffix"
  value       = tencentcloud_cos_bucket.audit.bucket
}

output "bucket_url" {
  description = "Audit log COS bucket access endpoint"
  value       = tencentcloud_cos_bucket.audit.cos_bucket_url
}

output "audit_track_name" {
  description = "Organization-wide CloudAudit track name"
  value       = tencentcloud_audit_track.org.name
}
