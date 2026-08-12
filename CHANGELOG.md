# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **Config validation now actually blocks bad plans.** The five config-consistency
  rules (department nesting/resolvability, account `department` references, guardrail
  `bound_to` references, `pay_uin` for delegated payment, central-logging
  prerequisites) moved from `checks.tf` into `variables.tf` `validation` blocks.
  Terraform `check` blocks only emit a *warning* and never block plan/apply, so the
  old placement let a misconfigured department silently disappear from the plan.
  `required_version` raised to `>= 1.9` (variable validations can now reference other
  variables).
- `checks.tf` now holds post-deploy runtime assertions (the only correct use of
  `check` blocks) and documents that they do not block operations.
- The `tencentcloud.log_archive` provider alias now uses a sentinel UIN in the
  assume-role ARN when central logging is disabled, so the role ARN stays
  well-formed (it is never actually configured while the module is not
  instantiated). Avoids a malformed empty-UIN ARN in the disabled state.
- `region` validation now accepts real 3-segment regions (e.g. `ap-shanghai-fsi`,
  `na-ashburn`) instead of rejecting them.
- `audit_log_retention_days` validation now rejects negative values.
- `locals.tf` sorts member UINs before chunking so batch policy attachment and
  baseline application stay deterministic when accounts are added or removed.
- `SecurityOps` identity narrowed to read-only on `cvm`/`vpc`/`cls` (was `*:*`),
  removing the contradiction with the `DenyDeleteCoreNetwork` SCP.

### Changed

- CI security scan pins `aquasecurity/trivy-action@v0.36.0` (was `@master`) and
  `checkov==3.3.10` instead of an unpinned install.

## [0.1.0] - 2026-08-10

Initial public release.

### Added

- Organization enablement, departments (with optional `parent` nesting, up to
  3 levels), core/business/sandbox account creation and finance permissions
- Identities (permission sets), member policy attachments and login
  authorization
- Guardrails (Service Control Policies) with data-driven policies and
  department attachment, including `DenyOrganizationTampering`,
  `DenyDeleteSecurityResources` and `DenyDeleteCoreNetwork` defaults
- Account factory baseline configuration and batch application, with
  automatic UIN chunking (10 per API call)
- Optional central audit logging: organization-wide CloudAudit track
  (`track_for_all_members`) delivering to a versioned, encrypted COS bucket
  in the log archive account (`modules/audit-logging`)
- Three-layer configuration validation: variable `validation` blocks,
  plan-time `check` blocks, and the standalone preflight script
  `scripts/validate-config.py`
- COS remote backend example with state locking (`backend.tf.example`)
- Makefile with staged deployment targets (`stage1` … `stage4`)
- GitHub Actions CI: fmt / validate / tflint / preflight / unit tests /
  optional plan, terraform-docs drift check, scenario example validation,
  advisory checkov + trivy scans, and scheduled drift detection
- Runnable scenario examples (`examples/minimal`, `examples/complete`)
- Preflight unit tests (`scripts/tests`, pytest)
- Auto-generated module reference in the README (terraform-docs)
- Dependabot configuration for Terraform providers and GitHub Actions
- pre-commit hooks (`.pre-commit-config.yaml`)
- Contribution, security and ownership docs (`CONTRIBUTING.md`,
  `SECURITY.md`, `CODEOWNERS`), issue and PR templates
- English and Chinese documentation (`README.md` / `README.zh-CN.md`)

[0.1.0]: https://github.com/susunola/tencentcloud-landingzone/releases/tag/v0.1.0
