# Security Policy

## Supported Versions

Only the latest release line receives security fixes.

| Version | Supported |
|---|---|
| latest release | ✅ |
| older releases | ❌ |

## Reporting a Vulnerability

**Please do not open a public issue for security vulnerabilities.**

Report vulnerabilities privately via
[GitHub Security Advisories](https://github.com/susunola/tencentcloud-landingzone/security/advisories/new).

Please include:

- the affected version (contents of the `VERSION` file or release tag)
- a description of the issue and its impact
- reproduction steps or a proof of concept, if available

You can expect an acknowledgment within 3 business days.

## Scope Notes

This repository contains Terraform configuration that provisions a Tencent
Cloud multi-account Landing Zone. Please **never** include real credentials
(SecretId/SecretKey), account UINs, or state file contents in issues, pull
requests, or advisory reports.
