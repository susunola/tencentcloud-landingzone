# =============================================================================
# 身份与权限（权限集）
# 对应控制中心 Landing Zone「身份与权限」配置：
#   1) 身份（权限集）：预设或自定义的策略集合
#   2) 成员策略：将身份绑定到成员账号
#   3) 登录授权：管理账号以指定身份登录成员账号（统一成员访问）
# =============================================================================

# -----------------------------------------------------------------------------
# 身份 1：组织管理员登录身份（预设 AdministratorAccess，CAM 预设策略 ID=1）
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_identity" "admin_login" {
  identity_alias_name = "OrganizationAdmin"
  description         = "组织管理员登录成员账号使用，预设 AdministratorAccess 权限"

  identity_policy {
    policy_type = 2 # 2=预设策略
    policy_id   = 1 # CAM 预设策略 ID，1=AdministratorAccess
    policy_name = "AdministratorAccess"
  }
}

# -----------------------------------------------------------------------------
# 身份 2：安全运维（自定义策略）
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_identity" "security_ops" {
  identity_alias_name = "SecurityOps"
  description         = "安全账号运维身份：安全产品 + 日志只读"

  identity_policy {
    policy_type = 1 # 1=自定义策略

    policy_document = jsonencode({
      version = "2.0"
      statement = [
        {
          effect = "allow"
          action = [
            "waf:*",
            "yunjing:*",
            "ssl:*",
            "cls:*",
            "cvm:*",
            "vpc:*",
          ]
          resource = ["*"]
        }
      ]
    })
  }
}

# -----------------------------------------------------------------------------
# 身份 3：只读审计（自定义策略，避免依赖预设策略 ID）
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_identity" "auditor" {
  identity_alias_name = "Auditor"
  description         = "全员只读审计身份"

  identity_policy {
    policy_type = 1

    policy_document = jsonencode({
      version = "2.0"
      statement = [
        {
          effect = "allow"
          action = [
            "cvm:Describe*",
            "vpc:Describe*",
            "cos:Get*",
            "cls:Describe*",
            "monitor:Describe*",
            "cloudaudit:Describe*",
            "config:Describe*",
            "cam:Get*",
            "cam:List*",
          ]
          resource = ["*"]
        }
      ]
    })
  }
}

# -----------------------------------------------------------------------------
# 成员策略：将「安全运维」身份绑定到安全账号
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_member_policy_attachment" "security_ops" {
  member_uins = [tencentcloud_organization_org_member.core["security"].id]
  policy_name = "SecurityOpsPolicy"
  identity_id = tencentcloud_organization_org_identity.security_ops.id
  description = "安全账号安全运维策略"
}

# -----------------------------------------------------------------------------
# 成员策略：将「只读审计」身份绑定到全部账号
# 注意：member_uins 单次最多 10 个，账号较多时需拆分多个资源
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_member_policy_attachment" "auditor" {
  member_uins = concat(
    [for m in tencentcloud_organization_org_member.core : m.id],
    [for m in tencentcloud_organization_org_member.business : m.id],
  )
  policy_name = "AuditorPolicy"
  identity_id = tencentcloud_organization_org_identity.auditor.id
  description = "全员只读审计策略"
}

# -----------------------------------------------------------------------------
# 登录授权：管理账号以「组织管理员」身份登录各业务账号
# 如需授权登录核心账号，将 for_each 改为 merge(core, business) 的并集
# -----------------------------------------------------------------------------
resource "tencentcloud_organization_org_member_auth_identity_attachment" "admin_login" {
  for_each = tencentcloud_organization_org_member.business

  member_uin   = each.value.id
  identity_ids = [tencentcloud_organization_org_identity.admin_login.id]
}
