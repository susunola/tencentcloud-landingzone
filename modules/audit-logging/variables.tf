variable "bucket_name" {
  description = "Audit log COS bucket name (without the -APPID suffix)"
  type        = string
}

variable "appid" {
  description = "APPID of the log archive account (COS bucket name suffix)"
  type        = string
}

variable "region" {
  description = "Region of the COS bucket"
  type        = string
}

variable "log_archive_uin" {
  description = "UIN of the log archive account (storage account of the audit track)"
  type        = string
}

variable "retention_days" {
  description = "Audit log retention in days, expired objects are deleted by a COS lifecycle rule; 0 keeps logs forever"
  type        = number
  default     = 365
}

variable "track_name" {
  description = "CloudAudit track name"
  type        = string
  default     = "org-audit-track"
}

variable "storage_prefix" {
  description = "Path prefix for log delivery inside the COS bucket"
  type        = string
  default     = "cloudaudit"
}

variable "tags" {
  description = "Tags applied to the COS bucket"
  type        = map(string)
  default     = {}
}
