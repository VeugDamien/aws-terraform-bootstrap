# aws-terraform-bootstrap

A clean starting point for a Terraform project on AWS, deployed by GitHub Actions without any AWS access key.

Fork this repository (or click **Use this template**) and start writing Terraform.

## Layout

```
bootstrap/bootstrap.yaml   # CloudFormation stack, deployed once per environment
modules/app/               # code shared by every environment
environments/
└── dev/                   # one folder = one environment (copy it for preprod, prod...)
    ├── main.tf            # calls the shared module with the values of this environment
    ├── backend.tf         # where the state of this environment lives
    ├── providers.tf       # region and default tags
    ├── versions.tf
    ├── outputs.tf
    └── ci.example.json    # rename to ci.json once filled: this activates the environment in CI
.github/workflows/         # plan on pull requests, apply on main
.terraform-version         # Terraform version used by the workflows
.tflint.hcl                # tflint rules
.trivyignore.yaml          # accepted security findings, with their reason
.github/rulesets/          # optional protection of main, to import (see below)
```

Each folder under `environments/` is an independent Terraform root with its own state. You always know which environment you work on: `cd environments/prod`.

## After creating your repository

"Use this template" copies the files only, not the repository settings. Do this once in your new repository:

- [ ] **Protect `main`** with the provided ruleset (optional, but recommended). It requires a pull request and the `fmt and validate`, `tflint` and `trivy` checks, and blocks force pushes and deletion:

  ```bash
  gh api -X POST repos/my-org/my-repo/rulesets --input .github/rulesets/protect-main.json
  ```

  Or in **Settings > Rules > Rulesets > New ruleset > Import a ruleset**. Edit the file first to adapt it: for a team, set `required_approving_review_count` to `1`. Rulesets on private repositories of a personal account need GitHub Pro.
- [ ] **Enable security features** in **Settings > Advanced Security**: Dependabot alerts, secret scanning and push protection.
- [ ] **Create the GitHub Environments** and set up each environment (next section).

## Add an environment

Do this once for each environment (`dev` is used below).

`environments/dev/` is an example with placeholder values. It is **inactive** until it contains a `ci.json`, so a fresh copy of this template runs no workflow against AWS.

### 1. Deploy the bootstrap stack

First check which OIDC subject format your repository uses:

```bash
gh api repos/my-org/my-repo/actions/oidc/customization/sub
```

If the answer contains `"use_immutable_subject": true` (the default for new repositories), GitHub sends subjects such as `repo:my-org@123/my-repo@456:pull_request`. Pass the numeric IDs to the stack:

```bash
gh api repos/my-org/my-repo --jq '"GitHubOwnerId=\(.owner.id) GitHubRepositoryId=\(.id)"'
```

In the AWS account of the environment, deploy `bootstrap/bootstrap.yaml` from the CloudFormation console or with:

```bash
aws cloudformation deploy \
  --template-file bootstrap/bootstrap.yaml \
  --stack-name my-app-dev-terraform-bootstrap \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    Project=my-app Environment=dev \
    GitHubOrganization=my-org GitHubRepository=my-repo \
    GitHubOwnerId=123 GitHubRepositoryId=456 \
  --tags my-company:project=my-app my-company:env=dev my-company:owner=team-a
```

- `Environment` must be the name of the folder.
- Leave out `GitHubOwnerId` and `GitHubRepositoryId` if the repository uses the classic format (`repo:my-org/my-repo:...`).
- If the account already has a GitHub OIDC provider, add `CreateOidcProvider=false ExistingOidcProviderArn=<its ARN>`. List them with `aws iam list-open-id-connect-providers`.

The stack creates:

- an S3 state bucket: versioned, encrypted, private, TLS only, kept if the stack is deleted;
- the GitHub OIDC provider (optional, only one per account);
- a **Plan role**, assumable by pull requests of your repository only: `ReadOnlyAccess`, read on the state, write on the lock file;
- an **Apply role**, assumable only by jobs running in the GitHub Environment named like the folder: full access to the state, plus the policies you give in `ApplyPolicyArns`.

### 2. Fill the environment folder

Create the folder from the example (skip for `dev`):

```bash
cp -R environments/dev environments/prod
```

Print the stack outputs:

```bash
aws cloudformation describe-stacks --stack-name my-app-dev-terraform-bootstrap \
  --query "Stacks[0].Outputs[].[OutputKey,OutputValue]" \
  --output text
```

- Copy `StateBucketName`, `StateKey` and `Region` into `backend.tf`.
- Rename `ci.example.json` to `ci.json` and replace its content with the output `CiJson`.
- Set the region, the tags and the module values in `providers.tf` and `main.tf`.

### 3. Create the GitHub Environment

In **Settings > Environments**, create an Environment with the same name as the folder. Add required reviewers where you want a manual approval (typically `prod`), and limit deployments to the `main` branch.

Do it **before** merging the `ci.json`: if the Environment does not exist, GitHub creates it on the first apply **without any protection**, and that apply runs without approval.

### 4. Check it locally

```bash
cd environments/dev
terraform init
terraform plan
```

Commit the folder with its `ci.json` and open a pull request: the workflows pick it up automatically.

## Tags

The bootstrap stack sets no tag of its own: use your company convention.

- **Bootstrap resources**: pass stack tags with `--tags Key=Value ...` (or in the console, step "Configure stack options"). CloudFormation applies them to every resource of the stack. Changing them later only needs a redeploy with the new tags.
- **Resources created by Terraform**: set `default_tags` in `environments/<env>/providers.tf`. They are applied to every taggable resource of the AWS provider.

Keys and values are free, within AWS limits: keys up to 128 characters, values up to 256, and no `aws:` prefix.

## Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `terraform-checks` | Pull request and push to `main` | `terraform fmt`, `terraform validate`, tflint and a trivy security scan. No AWS access |
| `terraform-plan` | Pull request to `main` | One plan per affected environment, all posted in a single PR comment |
| `terraform-apply` | Push to `main`, or manual run | One apply per affected environment, each in its GitHub Environment (approval if configured) |

Which environments run:

| Change in | Environments |
|-----------|--------------|
| `environments/<name>/` | `<name>` only |
| `modules/`, `.github/`, `.terraform-version` | all |
| anything else (README, `bootstrap/`...) | none |
| manual run of `terraform-apply` | all |

An environment is any folder under `environments/` that contains a `ci.json`. Folder names use `a-z`, `0-9` and `-`.

Environments are applied in parallel, each waiting for its own approval. For a strict order (dev, then preprod, then prod), adapt `terraform-apply.yml` to your project.

No secret and no repository variable is needed: the workflows read `ci.json` and get short-lived credentials through OIDC. Pull requests from forks never get credentials.

## Checks

`terraform-checks` runs on every pull request, including from forks, because it needs no AWS access:

| Check | Tool | Fails on |
|-------|------|----------|
| Formatting | `terraform fmt -check -recursive` | any file not formatted |
| Syntax and types | `terraform validate` in each `environments/*` and `modules/*` folder | any error |
| Lint | tflint, with the Terraform and AWS rule sets (`.tflint.hcl`) | any issue |
| Security | trivy, on the Terraform code and `bootstrap/bootstrap.yaml` | `HIGH` and `CRITICAL` findings |

Run them locally before pushing:

```bash
terraform fmt -recursive
tflint --init && tflint --recursive --config "$PWD/.tflint.hcl"
trivy config --severity HIGH,CRITICAL --ignorefile .trivyignore.yaml .
```

To accept a security finding, add it to `.trivyignore.yaml` with its ID, the files it applies to and the reason. One finding is accepted out of the box: the state bucket uses SSE-S3 instead of a customer managed KMS key (see the file).

To require the checks before merging, import the ruleset (see [After creating your repository](#after-creating-your-repository)).

## Give the Apply role permissions

The Apply role has **no AWS permissions by default**, only the state. The first apply works because the example only reads data. Before adding resources, redeploy the stack with a policy that covers what your code manages:

```bash
aws cloudformation deploy ... --parameter-overrides ... \
  ApplyPolicyArns=arn:aws:iam::aws:policy/PowerUserAccess
```

Prefer your own least-privilege policy in production. The Plan role keeps `ReadOnlyAccess`, so it can plan any change without making it.

## Good to know

- **`Not authorized to perform sts:AssumeRoleWithWebIdentity`**: the subject sent by GitHub does not match the role. The usual cause is the immutable subject format (see step 1). The exact subject is in CloudTrail, event `AssumeRoleWithWebIdentity`, field `userIdentity.userName`.

- **One account per environment** is the recommended setup. Several environments in one account also work: deploy the first stack with the OIDC provider, the next ones with `CreateOidcProvider=false`.
- **Required reviewers** on a private repository need a paid GitHub plan.
- **Removing an environment**: delete its folder, then its stack. The state bucket is kept on purpose. Empty and delete it by hand if you really want it gone.

## License

Apache License 2.0. See [LICENSE](LICENSE).
