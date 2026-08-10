# =============================================================================
# 防护规则（服务控制策略 SCP）
# 对应控制中心 Landing Zone「防护规则」配置
# SCP 只定义权限边界，不授予权限；绑定到部门后对部门及其下所有账号生效
# =============================================================================

# 开启集团策略（服务控制策略）能力
resource "tencentcloud_organization_org_manage_policy_config" "scp" {
  organization_id = tencentcloud_organization_instance.this.org_id
  policy_type     = "SERVICE_CONTROL_POLICY"
}

# 防护规则 1：禁止删除安全/合规/身份相关资源
resource "tencentcloud_organization_org_manage_policy" "deny_delete_security" {
  name        = "DenyDeleteSecurityResources"
  description = "禁止删除 CAM 身份、审计、日志与存储资源，保护安全合规资产"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    version = "2.0"
    statement = [
      {
        effect = "deny"
        action = [
          "cam:DeleteUser",
          "cam:DeleteRole",
          "cam:DeletePolicy",
          "cloudaudit:DeleteAudit",
          "cloudaudit:StopLogging",
          "config:DeleteConfigRule",
          "cls:DeleteLogset",
          "cls:DeleteTopic",
          "cos:DeleteBucket",
        ]
        resource = ["*"]
      }
    ]
  })
}

# 防护规则 2：禁止删除核心网络资源（由 Landing Zone 统一规划的共享网络）
resource "tencentcloud_organization_org_manage_policy" "deny_delete_network" {
  name        = "DenyDeleteCoreNetwork"
  description = "禁止删除 VPC、子网、NAT 网关等核心网络资源"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    version = "2.0"
    statement = [
      {
        effect = "deny"
        action = [
          "vpc:DeleteVpc",
          "vpc:DeleteSubnet",
          "vpc:DeleteNatGateway",
          "vpc:DeleteVpnGateway",
        ]
        resource = ["*"]
      }
    ]
  })
}

# 将防护规则绑定到业务部门（对部门及其下账号生效，可继续绑定到其他部门）
resource "tencentcloud_organization_org_manage_policy_target" "scp_business_security" {
  target_id   = tencentcloud_organization_org_node.this["business"].id
  target_type = "NODE"
  policy_id   = tencentcloud_organization_org_manage_policy.deny_delete_security.policy_id
  policy_type = "SERVICE_CONTROL_POLICY"
}

resource "tencentcloud_organization_org_manage_policy_target" "scp_business_network" {
  target_id   = tencentcloud_organization_org_node.this["business"].id
  target_type = "NODE"
  policy_id   = tencentcloud_organization_org_manage_policy.deny_delete_network.policy_id
  policy_type = "SERVICE_CONTROL_POLICY"
}
