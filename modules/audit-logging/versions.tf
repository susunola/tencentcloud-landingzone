terraform {
  required_version = ">= 1.5"

  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = ">= 1.82.50"
      # default provider = management account (organization-wide audit track)
      # log_archive     = log archive account (COS bucket)
      configuration_aliases = [tencentcloud.log_archive]
    }
  }
}
