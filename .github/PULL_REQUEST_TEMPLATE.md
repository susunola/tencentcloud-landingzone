## Summary

<!-- What does this change do and why? -->

## Checklist

- [ ] `terraform fmt -check -recursive` passes
- [ ] `terraform validate` passes
- [ ] `python3 scripts/validate-config.py` passes
- [ ] `python3 -m pytest scripts/tests -q` passes
- [ ] `terraform-docs -c .terraform-docs.yml .` produces no diff
- [ ] `README.md` and `README.zh-CN.md` are updated together
- [ ] `CHANGELOG.md` is updated (user-facing changes)
- [ ] All new/changed content outside README files is in English
- [ ] Existing state addresses are preserved, or migration steps are documented

## State Impact

<!-- Does this change rename, re-key or remove any resource? How do existing
     deployments migrate? -->
