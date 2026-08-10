# =============================================================================
# Provider configuration
# Credential precedence: terraform.tfvars variables > environment variables
# TENCENTCLOUD_SECRET_ID / TENCENTCLOUD_SECRET_KEY > shared credentials file
# ~/.tccli/credentials
# Organization / Control Center are global services; region is only used for
# regional resources (e.g. the baseline VPC)
# =============================================================================
provider "tencentcloud" {
  secret_id  = var.tencentcloud_secret_id
  secret_key = var.tencentcloud_secret_key
  region     = var.region
}

# -----------------------------------------------------------------------------
# Enable the Organization (group account management) service.
# This is the starting point of the whole Landing Zone, equivalent to enabling
# the organization before configuring the Landing Zone in Control Center.
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_instance" "this" {
  root_node_name = var.root_node_name
}
