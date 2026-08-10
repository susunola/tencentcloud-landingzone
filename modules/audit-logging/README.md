# audit-logging

Central audit logging module.

- COS bucket in the **log archive account** (versioning, AES256 server-side
  encryption, retention lifecycle), created through the
  `tencentcloud.log_archive` provider alias.
- Organization-wide CloudAudit track in the **management account**
  (`track_for_all_members = 1`) delivering operation logs of every member
  account to that bucket.

See the root README "Central Audit Logging" section for the one-time
prerequisite (CAM role in the log archive account).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.5 |
| tencentcloud | >= 1.82.50 |

## Providers

| Name | Version |
| ---- | ------- |
| tencentcloud | >= 1.82.50 |
| tencentcloud.log\_archive | >= 1.82.50 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [tencentcloud_audit_track.org](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/audit_track) | resource |
| [tencentcloud_cos_bucket.audit](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/cos_bucket) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| appid | APPID of the log archive account (COS bucket name suffix) | `string` | n/a | yes |
| bucket\_name | Audit log COS bucket name (without the -APPID suffix) | `string` | n/a | yes |
| log\_archive\_uin | UIN of the log archive account (storage account of the audit track) | `string` | n/a | yes |
| region | Region of the COS bucket | `string` | n/a | yes |
| retention\_days | Audit log retention in days, expired objects are deleted by a COS lifecycle rule; 0 keeps logs forever | `number` | `365` | no |
| storage\_prefix | Path prefix for log delivery inside the COS bucket | `string` | `"cloudaudit"` | no |
| tags | Tags applied to the COS bucket | `map(string)` | `{}` | no |
| track\_name | CloudAudit track name | `string` | `"org-audit-track"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| audit\_track\_name | Organization-wide CloudAudit track name |
| bucket\_name | Audit log COS bucket, full name with the -APPID suffix |
| bucket\_url | Audit log COS bucket access endpoint |
<!-- END_TF_DOCS -->
