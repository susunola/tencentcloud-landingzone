# Roadmap

Directions under consideration, roughly in priority order. Items here are
deliberately **not** implemented yet — each is recorded with its rationale so
contributors can pick one up with full context.

## Stage-split remote states

Split the single root state into per-domain stages (`00-org`, `10-governance`,
`20-baselines`, `30-logging`), each with its own COS backend, passing a
whitelisted contract of outputs forward via COS objects
(`tencentcloud_cos_bucket_object`) instead of `terraform_remote_state`.

Rationale: shrinks blast radius (SCP changes never touch the org/accounts
state) and replaces `apply -target` staging, which HashiCorp discourages as a
standing workflow. Deferred because it is a breaking layout change and needs
documented state migration.

## Bootstrap stage

A manually-run `bootstrap/` stage that creates the state bucket and
least-privilege CI roles (`ci-plan` read-only, `ci-apply` scoped), replacing
long-lived admin keys in GitHub Secrets. Blocked on verifying Tencent Cloud
CAM OIDC support for GitHub Actions; without OIDC it degrades to two scoped
keys.

## YAML data factories

One-file-per-account YAML factories (`data/accounts/*.yaml`,
`data/departments/**`) with JSON Schema validation, making "request an
account" a single-file PR. Deferred: tfvars + native validation is the better
trade at current scale; factories pay off when business teams self-service
accounts (roughly >20 accounts).

## E2E compliance assertions

Post-deploy assertions that guardrails actually deny what they should (via
Config rules or API probes against a sandbox organization). Deferred: no
existing framework covers Tencent Cloud; requires a disposable test
organization.

## OpenTofu CI matrix

Run `tofu fmt -check` / `tofu validate` alongside Terraform in CI once the
config avoids Terraform-only features, then declare compatibility in the
README.
