#!/usr/bin/env python3
"""Landing Zone 配置预检（借鉴 AWS LZA 的 config validation 思想）。

在 terraform plan 之前校验 terraform.tfvars(.json) 中的配置引用一致性，
给出友好报错，避免 plan/apply 到中途才发现引用错误。

依赖: python-hcl2（pip install python-hcl2）

用法:
    python3 scripts/validate-config.py [path/to/tfvars]
不传参数时自动探测 terraform.tfvars 或 terraform.tfvars.json。

校验项:
  1. departments 的 key 唯一
  2. core_accounts / business_accounts 的 department 必须存在于 departments
  3. member_permission_ids 必须包含 1、2；包含 7 时必须设置 pay_uin
  4. guardrail_policies 的 bound_to 必须存在于 departments
  5. baseline_config_items 的 identifier 非空
  6. enable_* 开关必须是 bool

说明: 未在 tfvars 中显式定义的变量使用 variables.tf 默认值；
departments 未定义时按默认部门 (core/business/sandbox) 校验。
"""

import json
import os
import sys

DEFAULT_DEPARTMENT_KEYS = ["core", "business", "sandbox"]
FINDING_FMT = "  [{}] {}"


def load_tfvars(path):
    """返回解析后的 dict，支持 HCL 与 JSON 两种 tfvars。"""
    if path.endswith(".json"):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    try:
        import hcl2
    except ImportError:
        print("[ERROR] 解析 HCL tfvars 需要 python-hcl2，请先安装: pip install python-hcl2")
        print("        或改用 JSON 格式的 terraform.tfvars.json")
        sys.exit(2)
    with open(path, encoding="utf-8") as f:
        return hcl2.load(f)


def clean(v):
    """python-hcl2 的字符串键值会保留引号（如 '"abc"'），递归去除。"""
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
        print("未找到 terraform.tfvars(.json)，跳过预检（将使用 variables.tf 默认值）。")
        return 0

    try:
        cfg = clean(load_tfvars(path))
    except Exception as e:  # noqa: BLE001
        print(f"[ERROR] 解析 {path} 失败: {e}")
        return 1

    findings = []

    # 1) departments
    depts = cfg.get("departments")
    if depts is None:
        dept_keys = DEFAULT_DEPARTMENT_KEYS
        findings.append(("WARN", "departments 未在 tfvars 定义，按默认 (core/business/sandbox) 校验"))
    else:
        dept_keys = [d.get("key") for d in depts if isinstance(d, dict) and d.get("key")]
        seen, dup = set(), set()
        for k in dept_keys:
            if k in seen:
                dup.add(k)
            seen.add(k)
        for d in dup:
            findings.append(("ERROR", f"departments 存在重复 key: {d}"))
    dept_set = set(dept_keys)

    # 2) 账号的 department 引用
    def check_dept(owner, accounts):
        if not isinstance(accounts, (list, dict)):
            return
        items = accounts.items() if isinstance(accounts, dict) else enumerate(accounts)
        for name, acc in items:
            if not isinstance(acc, dict):
                continue
            dep = acc.get("department")
            if dep is None:
                findings.append(("WARN", f"{owner} 中 '{name}' 未指定 department"))
            elif dep not in dept_set:
                findings.append(("ERROR", f"{owner} 中 '{name}' 的 department '{dep}' 不存在于 departments: {sorted(dept_set)}"))

    check_dept("core_accounts", cfg.get("core_accounts", []))
    check_dept("business_accounts", cfg.get("business_accounts", {}))

    # 3) 财务权限
    perms = cfg.get("member_permission_ids")
    if isinstance(perms, list):
        nums = [p for p in perms if isinstance(p, int)]
        if not (1 in nums and 2 in nums):
            findings.append(("ERROR", "member_permission_ids 必须包含 1(查账单) 和 2(查余额)"))
        if 7 in nums and not cfg.get("pay_uin"):
            findings.append(("ERROR", "member_permission_ids 包含 7(代付) 时必须设置 pay_uin"))

    # 4) 防护规则绑定目标
    gp = cfg.get("guardrail_policies")
    if isinstance(gp, dict):
        for name, p in gp.items():
            if not isinstance(p, dict):
                continue
            for t in p.get("bound_to", []):
                if t not in dept_set:
                    findings.append(("ERROR", f"guardrail_policies['{name}'] 绑定目标 '{t}' 不存在于 departments: {sorted(dept_set)}"))

    # 5) 基线项
    bi = cfg.get("baseline_config_items")
    if isinstance(bi, list):
        for i, item in enumerate(bi):
            if isinstance(item, dict) and not item.get("identifier"):
                findings.append(("ERROR", f"baseline_config_items[{i}] 缺少 identifier"))

    # 6) 开关类型
    for k, v in cfg.items():
        if k.startswith("enable_") and not isinstance(v, bool):
            findings.append(("ERROR", f"{k} 必须是 bool (true/false)，当前为 {v!r}"))

    if not findings:
        print(f"\u2714 配置预检通过: {path}")
        return 0

    for level, msg in findings:
        print(FINDING_FMT.format(level, msg))
    errs = [f for f in findings if f[0] == "ERROR"]
    print(f"\n共 {len(findings)} 条发现（{len(errs)} 条错误）: {path}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
