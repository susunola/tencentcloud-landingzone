"""Unit tests for scripts/validate-config.py.

Runs the preflight script as a subprocess against JSON tfvars written to a
temp directory (JSON keeps the tests hermetic — no python-hcl2 dependency).
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "validate-config.py"

VALID_DEPARTMENTS = [
    {"key": "core", "name": "Core", "remark": ""},
    {"key": "business", "name": "Business", "remark": ""},
    {"key": "prod", "name": "Prod", "remark": "", "parent": "business"},
    {"key": "proj-x", "name": "ProjectX", "remark": "", "parent": "prod"},
]


def run_preflight(tmp_path, config):
    tfvars = tmp_path / "terraform.tfvars.json"
    tfvars.write_text(json.dumps(config), encoding="utf-8")
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(tfvars)],
        capture_output=True,
        text=True,
    )


def test_valid_nested_config_passes(tmp_path):
    result = run_preflight(tmp_path, {
        "departments": VALID_DEPARTMENTS,
        "business_accounts": {
            "app-prod": {"name": "AppA", "remark": "", "department": "prod"},
        },
    })
    assert result.returncode == 0, result.stdout
    assert "Preflight passed" in result.stdout


def test_duplicate_department_key_fails(tmp_path):
    result = run_preflight(tmp_path, {
        "departments": [
            {"key": "core", "name": "Core", "remark": ""},
            {"key": "core", "name": "Core Again", "remark": ""},
        ],
    })
    assert result.returncode == 1
    assert "duplicate key: core" in result.stdout


def test_parent_cycle_fails(tmp_path):
    result = run_preflight(tmp_path, {
        "departments": [
            {"key": "a", "name": "A", "remark": "", "parent": "b"},
            {"key": "b", "name": "B", "remark": "", "parent": "a"},
        ],
    })
    assert result.returncode == 1
    assert "cycle in its parent chain" in result.stdout


def test_nesting_deeper_than_three_levels_fails(tmp_path):
    result = run_preflight(tmp_path, {
        "departments": VALID_DEPARTMENTS + [
            {"key": "too-deep", "name": "Deep", "remark": "", "parent": "proj-x"},
        ],
    })
    assert result.returncode == 1
    assert "nested 4 levels deep" in result.stdout


def test_dangling_parent_fails(tmp_path):
    result = run_preflight(tmp_path, {
        "departments": [
            {"key": "a", "name": "A", "remark": "", "parent": "missing"},
        ],
    })
    assert result.returncode == 1
    assert "does not exist in departments" in result.stdout


def test_account_department_reference_fails(tmp_path):
    result = run_preflight(tmp_path, {
        "business_accounts": {
            "app": {"name": "App", "remark": "", "department": "no-such-dept"},
        },
    })
    assert result.returncode == 1
    assert "no-such-dept" in result.stdout


def test_delegated_payment_without_pay_uin_fails(tmp_path):
    result = run_preflight(tmp_path, {"member_permission_ids": [1, 2, 7]})
    assert result.returncode == 1
    assert "pay_uin" in result.stdout


def test_guardrail_bound_to_unknown_department_fails(tmp_path):
    result = run_preflight(tmp_path, {
        "guardrail_policies": {
            "DenySomething": {
                "description": "x",
                "bound_to": ["unknown-dept"],
                "content": '{"version": "2.0"}',
            },
        },
    })
    assert result.returncode == 1
    assert "unknown-dept" in result.stdout


def test_central_logging_prerequisites_fail(tmp_path):
    result = run_preflight(tmp_path, {"enable_central_logging": True})
    assert result.returncode == 1
    assert "audit_log_bucket_name" in result.stdout
    assert "log_archive_appid" in result.stdout


def test_enable_flag_type_fails(tmp_path):
    result = run_preflight(tmp_path, {"enable_guardrails": "yes"})
    assert result.returncode == 1
    assert "must be a bool" in result.stdout


def test_missing_tfvars_is_a_clean_skip(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        capture_output=True,
        text=True,
        cwd=tmp_path,
    )
    assert result.returncode == 0
    assert "skipping preflight" in result.stdout


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-q"]))
