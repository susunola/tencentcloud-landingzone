# Landing Zone command entry points
# Usage: make help

TF := terraform

.PHONY: help init fmt validate preflight plan apply stage1 stage2 stage3 stage4 output

help: ## Show available commands
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-12s %s\n", $$1, $$2}'

init: ## terraform init
	$(TF) init

fmt: ## Format all tf files
	$(TF) fmt -recursive

validate: ## terraform validate (including check block syntax)
	$(TF) validate

preflight: ## Config preflight (reference consistency, no cloud credentials needed)
	python3 scripts/validate-config.py

plan: preflight ## Preflight + terraform plan
	$(TF) plan

apply: ## terraform apply
	$(TF) apply

# --- Staged deployment (see README "Phased Deployment") ---

stage1: ## Stage 1: organization and accounts
	$(TF) apply \
	  -target=tencentcloud_organization_instance.this \
	  -target=tencentcloud_organization_org_node.this \
	  -target=tencentcloud_organization_org_node.level2 \
	  -target=tencentcloud_organization_org_node.level3 \
	  -target=tencentcloud_organization_org_member.core \
	  -target=tencentcloud_organization_org_member.business

stage2: ## Stage 2: identities and guardrails
	$(TF) apply \
	  -target=tencentcloud_organization_org_identity.admin_login \
	  -target=tencentcloud_organization_org_identity.security_ops \
	  -target=tencentcloud_organization_org_identity.auditor \
	  -target=tencentcloud_organization_org_member_policy_attachment.security_ops \
	  -target=tencentcloud_organization_org_member_policy_attachment.auditor \
	  -target=tencentcloud_organization_org_member_auth_identity_attachment.admin_login \
	  -target=tencentcloud_organization_org_manage_policy_config.scp \
	  -target=tencentcloud_organization_org_manage_policy.this \
	  -target=tencentcloud_organization_org_manage_policy_target.this

stage3: ## Stage 3: account factory baselines
	$(TF) apply \
	  -target=tencentcloud_controlcenter_account_factory_baseline_config.default \
	  -target=tencentcloud_batch_apply_account_baselines.all

stage4: ## Stage 4: full reconciliation (including optional central audit logging)
	$(TF) apply

output: ## Show outputs
	$(TF) output
