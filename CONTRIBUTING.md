# Contributing

Thanks for your interest in improving this Landing Zone. This document
describes the conventions that keep the repository consistent.

## Design Principles

1. **Data-driven, not code-driven.** Adding a department, account, guardrail
   or baseline item must be possible by editing `terraform.tfvars` only.
   If a change requires new code, structure it so the next similar change
   does not.
2. **Feature flags for every module.** Each capability must be individually
   disableable via an `enable_*` variable.
3. **Fail before apply.** Any configuration error that can be detected
   statically must be caught by a variable `validation` block, a `check`
   block, or `scripts/validate-config.py` — never first at apply time.
4. **State compatibility.** Renaming or re-keying resources must either
   preserve existing state addresses or ship with documented migration
   steps.

## Development Workflow

```bash
make fmt          # terraform fmt -recursive
make validate     # terraform validate
make preflight    # tfvars reference-consistency check
```

Before opening a pull request:

- `terraform fmt -check -recursive` passes
- `terraform validate` passes
- `python3 scripts/validate-config.py` passes
- preflight unit tests pass: `python3 -m pytest scripts/tests -q`
- documentation is regenerated: `terraform-docs -c .terraform-docs.yml .`
- both `README.md` (EN) and `README.zh-CN.md` (ZH) are updated together

A `.pre-commit-config.yaml` is provided; `pre-commit install` enables fmt /
validate / docs checks on every commit.

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(guardrails): add DenyPublicBucket SCP
fix(organization): resolve level-3 parent lookup
docs: clarify central logging prerequisite
```

Common scopes: `organization`, `identities`, `guardrails`, `baselines`,
`logging`, `ci`, `docs`.

## Language Policy

All code, comments, commit messages and tooling output are in **English**.
The Chinese narrative documentation lives in `README.zh-CN.md` and must be
kept in sync with `README.md`.

## Versioning

Releases follow SemVer. The current version lives in the `VERSION` file and
changes are recorded in `CHANGELOG.md` (Keep a Changelog format).
