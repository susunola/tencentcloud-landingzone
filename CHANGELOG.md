# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
