# =============================================================================
# General
# =============================================================================
variable "tencentcloud_secret_id" {
  description = "Tencent Cloud API SecretId; leave null to use the TENCENTCLOUD_SECRET_ID environment variable"
  type        = string
  default     = null
  sensitive   = true
}

variable "tencentcloud_secret_key" {
  description = "Tencent Cloud API SecretKey; leave null to use the TENCENTCLOUD_SECRET_KEY environment variable"
  type        = string
  default     = null
  sensitive   = true
}

variable "region" {
  description = "Tencent Cloud region. Organization / Control Center are global services; this is only used for regional resources (e.g. the baseline VPC)"
  type        = string
  default     = "ap-guangzhou"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+$", var.region))
    error_message = "region must be a region identifier like ap-guangzhou"
  }
}

variable "root_node_name" {
  description = "Organization root node name (root department under the management account)"
  type        = string
  default     = "Root"
}

variable "tags" {
  description = "Global tags applied to taggable resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "LandingZone"
  }
}

# =============================================================================
# Feature flags: set to false to skip the whole module
# =============================================================================
variable "enable_guardrails" {
  description = "Whether to create and attach guardrails (Service Control Policies); false disables the whole guardrail module"
  type        = bool
  default     = true
}

variable "enable_baselines" {
  description = "Whether to configure and batch-apply account factory baselines; false disables the whole baseline module"
  type        = bool
  default     = true
}

variable "enable_login_permission" {
  description = "Whether to allow the management account to log in to business accounts as administrator (login authorization)"
  type        = bool
  default     = true
}

variable "enable_auditor_policy" {
  description = "Whether to bind the read-only auditor identity to all accounts"
  type        = bool
  default     = true
}

# =============================================================================
# Departments (organizational units) and accounts
# =============================================================================
variable "departments" {
  description = <<-EOT
    Department (organizational unit) list. key is the resource identifier, name is the display name.
    Maps to the "Departments" section of the Control Center Landing Zone.
    parent is optional: set it to another department key to create a sub-department
    (up to 3 levels: root -> L1 -> L2 -> L3); null (default) attaches to the organization root.
  EOT
  type = list(object({
    key    = string
    name   = string
    remark = string
    parent = optional(string, null)
  }))
  default = [
    { key = "core", name = "Core", remark = "Hosts security, logging and finance core accounts" },
    { key = "business", name = "Business", remark = "Production business accounts" },
    { key = "sandbox", name = "Sandbox", remark = "Test and experiment accounts; must not host production workloads" },
  ]

  validation {
    condition     = length(var.departments) == length(distinct([for d in var.departments : d.key]))
    error_message = "departments keys must be unique"
  }
}

variable "core_accounts" {
  description = <<-EOT
    Core accounts (key accounts managed by the management account), mapping to the
    "Core Accounts" section of the Control Center Landing Zone.
    Each element: key (resource identifier), name, department (must be a departments key), remark.
  EOT
  type = list(object({
    key        = string
    name       = string
    department = string
    remark     = string
  }))
  default = [
    { key = "security", name = "Security", department = "core", remark = "Centralized security products (WAF, host security, etc.)" },
    { key = "logging", name = "Logging", department = "core", remark = "Centralized collection of operation audit and config audit logs" },
    { key = "finance", name = "Finance", department = "core", remark = "Finance reconciliation and cost analysis" },
  ]
}

variable "business_accounts" {
  description = <<-EOT
    Business/sandbox accounts. Map key is the resource identifier; department must be a departments key.
    Maps to the "Account Creation / Invitation" section of the Control Center Landing Zone.
  EOT
  type = map(object({
    name       = string
    remark     = string
    department = string
  }))
  default = {
    "app-prod" = {
      name       = "AppA-Production"
      remark     = "Production business account"
      department = "business"
    }
    "dev-test" = {
      name       = "DevTest"
      remark     = "Sandbox test account"
      department = "sandbox"
    }
  }
}

# =============================================================================
# Finance
# =============================================================================
variable "member_permission_ids" {
  description = <<-EOT
    Member finance permissions (maps to the Landing Zone "Finance" section):
    1 view bills, 2 view balance, 3 fund transfer, 4 consolidated billing,
    5 invoicing, 6 discount inheritance, 7 delegated payment.
    Must include 1 and 2; pay_uin is required when 7 is included.
  EOT
  type        = list(number)
  default     = [1, 2, 4]

  validation {
    condition     = contains(var.member_permission_ids, 1) && contains(var.member_permission_ids, 2)
    error_message = "member_permission_ids must include 1 (view bills) and 2 (view balance)"
  }
}

variable "pay_uin" {
  description = "Delegated payment account UIN; only required when member_permission_ids includes 7"
  type        = string
  default     = null
}

# =============================================================================
# Guardrails (Service Control Policies)
# Extend: add/remove map entries; trim: empty the map or disable the flag
# =============================================================================
variable "guardrail_policies" {
  description = <<-EOT
    Guardrail (SCP) map. Map key is the policy name; bound_to lists department keys
    to attach (must be departments keys). content is a CAM policy syntax JSON document.
  EOT
  type = map(object({
    description = string
    content     = string
    bound_to    = list(string)
  }))
  default = {
    DenyOrganizationTampering = {
      description = "Deny member accounts quitting the organization or mutating organization members/nodes; structure changes are reserved for the management account"
      bound_to    = ["core", "business", "sandbox"]
      content     = <<-EOT
      {
        "version": "2.0",
        "statement": [
          {
            "effect": "deny",
            "action": [
              "organization:QuitOrganization",
              "organization:DeleteOrganizationMembers",
              "organization:DeleteOrganizationNodes",
              "organization:MoveOrganizationNode",
              "organization:UpdateOrganizationNode",
              "organization:UpdateOrganizationMembers"
            ],
            "resource": ["*"]
          }
        ]
      }
      EOT
    }
    DenyDeleteSecurityResources = {
      description = "Deny deleting CAM identities, audit, logging and storage resources to protect security and compliance assets"
      bound_to    = ["business"]
      content     = <<-EOT
      {
        "version": "2.0",
        "statement": [
          {
            "effect": "deny",
            "action": [
              "cam:DeleteUser",
              "cam:DeleteRole",
              "cam:DeletePolicy",
              "cloudaudit:DeleteAudit",
              "cloudaudit:StopLogging",
              "cloudaudit:DeleteAuditTrack",
              "cloudaudit:ModifyAuditTrack",
              "config:DeleteConfigRule",
              "cls:DeleteLogset",
              "cls:DeleteTopic",
              "cos:DeleteBucket"
            ],
            "resource": ["*"]
          }
        ]
      }
      EOT
    }
    DenyDeleteCoreNetwork = {
      description = "Deny deleting core network resources such as VPCs, subnets and NAT gateways"
      bound_to    = ["business"]
      content     = <<-EOT
      {
        "version": "2.0",
        "statement": [
          {
            "effect": "deny",
            "action": [
              "vpc:DeleteVpc",
              "vpc:DeleteSubnet",
              "vpc:DeleteNatGateway",
              "vpc:DeleteVpnGateway"
            ],
            "resource": ["*"]
          }
        ]
      }
      EOT
    }
  }

  validation {
    condition     = alltrue([for name, p in var.guardrail_policies : can(jsondecode(p.content))])
    error_message = "guardrail_policies content must be valid JSON"
  }

  validation {
    condition     = alltrue([for name, p in var.guardrail_policies : length(p.bound_to) > 0])
    error_message = "guardrail_policies bound_to must not be empty; attach to at least one department"
  }
}

# =============================================================================
# Account factory baselines
# Extend: add/remove list entries; trim: empty the list or disable the flag
# =============================================================================
variable "baseline_name" {
  description = "Account factory baseline name; must be unique"
  type        = string
  default     = "default"
}

variable "baseline_config_items" {
  description = <<-EOT
    Account factory baseline item list (identifier + configuration JSON); add or remove as needed.
    Identifiers can be listed via data source tencentcloud_controlcenter_account_factory_baseline_items.
  EOT
  type = list(object({
    identifier    = string
    configuration = string
  }))
  default = [
    {
      identifier    = "TCC-AF_PRESET_TAG"
      configuration = <<-EOT
      {
        "TagValuePairs": [
          { "Key": "Environment", "Values": ["managed"] }
        ]
      }
      EOT
    },
    {
      identifier    = "TCC-AF_VPC_SUBNET"
      configuration = <<-EOT
      {
        "VpcName": "default-vpc",
        "CidrBlock": "10.0.0.0/16",
        "Region": 1,
        "RegionName": "ap-guangzhou",
        "Subnets": [
          { "CidrBlock": "10.0.1.0/24", "SubnetName": "app", "Zone": "ap-guangzhou-6" },
          { "CidrBlock": "10.0.2.0/24", "SubnetName": "db",  "Zone": "ap-guangzhou-6" }
        ]
      }
      EOT
    },
  ]
}

# =============================================================================
# Central audit logging (maps to the Control Center "Compliance Audit" section)
# Disabled by default: a CAM role must be pre-created once in the log archive
# account; see logging.tf comments and README.
# =============================================================================
variable "enable_central_logging" {
  description = "Whether to create an organization-wide CloudAudit track (track_for_all_members) delivering all member operation logs to a COS bucket in the log archive account"
  type        = bool
  default     = false
}

variable "log_archive_account_key" {
  description = "Key of the log archive account in core_accounts (its UIN is used as the audit log storage account)"
  type        = string
  default     = "logging"
}

variable "log_archive_role_name" {
  description = "Name of the CAM role pre-created in the log archive account; the management account assumes it to create/maintain the COS bucket"
  type        = string
  default     = "LandingZoneLogArchiveAccess"
}

variable "log_archive_appid" {
  description = "APPID of the log archive account (COS bucket names require the -APPID suffix); required when enable_central_logging = true"
  type        = string
  default     = null
}

variable "audit_log_bucket_name" {
  description = "Audit log COS bucket name (without the -APPID suffix, globally unique); required when enable_central_logging = true"
  type        = string
  default     = null

  validation {
    condition     = var.audit_log_bucket_name == null || can(regex("^[a-z0-9][a-z0-9-]{1,50}$", var.audit_log_bucket_name))
    error_message = "audit_log_bucket_name may only contain lowercase letters, digits and hyphens (without the -APPID suffix)"
  }
}

variable "audit_log_retention_days" {
  description = "Audit log retention in days, expired objects are deleted by a COS lifecycle rule; 0 keeps logs forever"
  type        = number
  default     = 365
}
