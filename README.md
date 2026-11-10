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
    └── ci.json            # region and role ARNs used by the workflows
.github/workflows/         # plan on pull requests, apply on main
.terraform-version         # Terraform version used by the workflows
```

Each folder under `environments/` is an independent Terraform root with its own state. You always know which environment you work on: `cd environments/prod`.

## Add an environment

Do this once for each environment (`dev` is used below; `environments/dev/` holds placeholder values).

### 1. Deploy the bootstrap stack

In the AWS account of the environment, deploy `bootstrap/bootstrap.yaml` from the CloudFormation console or with:

```bash
aws cloudformation deploy \
  --template-file bootstrap/bootstrap.yaml \
  --stack-name my-app-dev-terraform-bootstrap \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    Project=my-app Environment=dev \
    GitHubOrganization=my-org GitHubRepository=my-repo
```

`Environment` must be the name of the folder. If the account already has a GitHub OIDC provider, add `CreateOidcProvider=false ExistingOidcProviderArn=<its ARN>`.

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
- Paste `CiJson` in `ci.json`.
- Set the region, the tags and the module values in `providers.tf` and `main.tf`.

### 3. Create the GitHub Environment

In **Settings > Environments**, create an Environment with the same name as the folder. Add required reviewers where you want a manual approval (typically `prod`), and limit deployments to the `main` branch.

### 4. Check it locally

```bash
cd environments/dev
terraform init
terraform plan
```

Open a pull request: the workflows pick the new folder up automatically.

## Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
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

## Give the Apply role permissions

The Apply role has **no AWS permissions by default**, only the state. The first apply works because the example only reads data. Before adding resources, redeploy the stack with a policy that covers what your code manages:

```bash
aws cloudformation deploy ... --parameter-overrides ... \
  ApplyPolicyArns=arn:aws:iam::aws:policy/PowerUserAccess
```

Prefer your own least-privilege policy in production. The Plan role keeps `ReadOnlyAccess`, so it can plan any change without making it.

## Good to know

- **Protect `main`**: require a pull request before merging, and the plan as a status check.
- **One account per environment** is the recommended setup. Several environments in one account also work: deploy the first stack with the OIDC provider, the next ones with `CreateOidcProvider=false`.
- **Required reviewers** on a private repository need a paid GitHub plan.
- **Removing an environment**: delete its folder, then its stack. The state bucket is kept on purpose. Empty and delete it by hand if you really want it gone.

## License

Apache License 2.0. See [LICENSE](LICENSE).
