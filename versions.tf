terraform {
  # >= 1.5: checks.tf uses check blocks; nested department optional attributes
  # require >= 1.3
  required_version = ">= 1.5"

  required_providers {
    tencentcloud = {
      source = "tencentcloudstack/tencentcloud"
      # Control Center account factory baseline resources are available since v1.82.44
      version = ">= 1.82.50"
    }
  }
}
