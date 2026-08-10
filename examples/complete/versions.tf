# Examples must declare their own Terraform requirements; the module
# constraints are inherited from the root module's versions.tf.
terraform {
  required_version = ">= 1.5"

  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = ">= 1.82.50"
    }
  }
}
