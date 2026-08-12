terraform {
  # >= 1.9: variable validation blocks reference other variables (config
  # consistency checks moved from checks.tf into variables.tf). Nested
  # department optional attributes require >= 1.3.
  required_version = ">= 1.9"

  required_providers {
    tencentcloud = {
      source = "tencentcloudstack/tencentcloud"
      # Control Center account factory baseline resources are available since v1.82.44
      version = ">= 1.82.50"
    }
  }
}
