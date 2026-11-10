# Security policy

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Report it privately from the **Security** tab of this repository: **Report a vulnerability**. You will get an answer as soon as possible, and the fix will be published with a security advisory.

Useful details: the affected file (for example `bootstrap/bootstrap.yaml` or a workflow), what an attacker could do, and how to reproduce it.

## Scope

In scope: the bootstrap stack (state bucket, OIDC provider, IAM roles and their trust policies) and the GitHub Actions workflows.

Out of scope: the Terraform code you add in `environments/` and `modules/`, and the permissions you grant to the Apply role through `ApplyPolicyArns`.
