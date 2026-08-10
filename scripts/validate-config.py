#!/usr/bin/env python3
"""Landing Zone configuration preflight.

Validates reference consistency in terraform.tfvars(.json) before
terraform plan, producing friendly errors instead of failing halfway
through a plan/apply.

Dependency: python-hcl2 (pip install python-hcl2)

Usage:
    python3 scripts/validate-config.py [path/to/tfvars]
Without arguments, terraform.tfvars or terraform.tfvars.json is auto-detected.

Checks:
  1. departments keys are unique
  2. departments parents exist, are not self-references, cycles or deeper
     than 3 levels
  3. core_accounts / business_accounts departments exist in departments
  4. member_permission_ids includes 1 and 2; pay_uin is set when 7 is included
  5. guardrail_policies bound_to targets exist in departments
  6. baseline_config_items identifiers are non-empty
  7. enable_* flags are booleans
  8. audit_log_bucket_name and log_archive_appid are set when
     enable_central_logging = true

Note: variables not explicitly set in tfvars fall back to variables.tf
defaults; when departments is undefined, the default departments
(core/business/sandbox) are assumed.
"""

import json
import os
import sys

DEFAULT_DEPARTMENT_KEYS = ["core", "business", "sandbox"]
FINDING_FMT = "  [{}] {}"


def load_tfvars(path):
    """Return the parsed tfvars as a dict; supports both HCL and JSON."""
    if path.endswith(".json"):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    try:
        import hcl2
    except ImportError:
        print("[ERROR] Parsing HCL tfvars requires python-hcl2: pip install python-hcl2")
        print("        or use a JSON-formatted terraform.tfvars.json instead")
        sys.exit(2)
    with open(path, encoding="utf-8") as f:
        return hcl2.load(f)


def clean(v):
    """python-hcl2 keeps quotes in string keys/values (e.g. '"abc"'); strip them recursively."""
    if isinstance(v, str) and len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        return v[1:-1]
    if isinstance(v, list):
        return [clean(x) for x in v]
    if isinstance(v, dict):
        return {clean(k): clean(x) for k, x in v.items()}
    return v


def main():
    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        for cand in ("terraform.tfvars.json", "terraform.tfvars"):
            if os.path.exists(cand):
                path = cand
                break
        else:
            path = None

    if path is None:
        print("No terraform.tfvars(.json) found; skipping preflight (variables.tf defaults will be used).")
        return 0

    try:
        cfg = clean(load_tfvars(path))
    except Exception as e:  # noqa: BLE001
        print(f"[ERROR] Failed to parse {path}: {e}")
        return 1

    findings = []

    # 1) departments
    depts = cfg.get("departments")
    if depts is None:
        dept_keys = DEFAULT_DEPARTMENT_KEYS
        dept_parents = {}
        findings.append(("WARN", "departments not defined in tfvars; validating against defaults (core/business/sandbox)"))
    else:
        dept_keys = [d.get("key") for d in depts if isinstance(d, dict) and d.get("key")]
        seen, dup = set(), set()
        for k in dept_keys:
            if k in seen:
                dup.add(k)
            seen.add(k)
        for d in dup:
            findings.append(("ERROR", f"departments has duplicate key: {d}"))
        dept_parents = {d["key"]: d.get("parent") for d in depts if isinstance(d, dict) and d.get("key")}
    dept_set = set(dept_keys)

    # 1b) department nesting: parent existence, self-reference, cycles, depth (max 3 levels)
    for k, parent in dept_parents.items():
        if parent is None:
            continue
        if parent == k:
            findings.append(("ERROR", f"departments '{k}' must not use itself as parent"))
        elif parent not in dept_set:
            findings.append(("ERROR", f"departments '{k}' parent '{parent}' does not exist in departments: {sorted(dept_set)}"))

    def depth_of(key):
        """Walk up the parent chain counting levels; returns None on cycles."""
        depth, seen, cur = 1, set(), key
        while dept_parents.get(cur) is not None:
            if cur in seen:
                return None
            seen.add(cur)
            cur = dept_parents[cur]
            depth += 1
        return depth

    for k in dept_parents:
        dep = depth_of(k)
        if dep is None:
            findings.append(("ERROR", f"departments '{k}' has a cycle in its parent chain"))
        elif dep > 3:
            findings.append(("ERROR", f"departments '{k}' is nested {dep} levels deep; at most 3 are supported (root -> L1 -> L2 -> L3)"))

    # 2) account department references
    def check_dept(owner, accounts):
        if not isinstance(accounts, (list, dict)):
            return
        items = accounts.items() if isinstance(accounts, dict) else enumerate(accounts)
        for name, acc in items:
            if not isinstance(acc, dict):
                continue
            dep = acc.get("department")
            if dep is None:
                findings.append(("WARN", f"{owner} entry '{name}' has no department"))
            elif dep not in dept_set:
                findings.append(("ERROR", f"{owner} entry '{name}' references department '{dep}' which does not exist in departments: {sorted(dept_set)}"))

    check_dept("core_accounts", cfg.get("core_accounts", []))
    check_dept("business_accounts", cfg.get("business_accounts", {}))

    # 3) finance permissions
    perms = cfg.get("member_permission_ids")
    if isinstance(perms, list):
        nums = [p for p in perms if isinstance(p, int)]
        if not (1 in nums and 2 in nums):
            findings.append(("ERROR", "member_permission_ids must include 1 (view bills) and 2 (view balance)"))
        if 7 in nums and not cfg.get("pay_uin"):
            findings.append(("ERROR", "pay_uin must be set when member_permission_ids includes 7 (delegated payment)"))

    # 4) guardrail attachment targets
    gp = cfg.get("guardrail_policies")
    if isinstance(gp, dict):
        for name, p in gp.items():
            if not isinstance(p, dict):
                continue
            for t in p.get("bound_to", []):
                if t not in dept_set:
                    findings.append(("ERROR", f"guardrail_policies['{name}'] bound_to target '{t}' does not exist in departments: {sorted(dept_set)}"))

    # 5) baseline items
    bi = cfg.get("baseline_config_items")
    if isinstance(bi, list):
        for i, item in enumerate(bi):
            if isinstance(item, dict) and not item.get("identifier"):
                findings.append(("ERROR", f"baseline_config_items[{i}] is missing identifier"))

    # 6) flag types
    for k, v in cfg.items():
        if k.startswith("enable_") and not isinstance(v, bool):
            findings.append(("ERROR", f"{k} must be a bool (true/false), got {v!r}"))

    # 7) central audit logging prerequisites
    if cfg.get("enable_central_logging") is True:
        if not cfg.get("audit_log_bucket_name"):
            findings.append(("ERROR", "audit_log_bucket_name must be set when enable_central_logging = true"))
        if not cfg.get("log_archive_appid"):
            findings.append(("ERROR", "log_archive_appid must be set when enable_central_logging = true"))

    if not findings:
        print(f"✔ Preflight passed: {path}")
        return 0

    for level, msg in findings:
        print(FINDING_FMT.format(level, msg))
    errs = [f for f in findings if f[0] == "ERROR"]
    print(f"\n{len(findings)} finding(s), {len(errs)} error(s): {path}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
