# TFLint configuration, used locally and by the terraform-checks workflow.
# Run locally from the repository root:
#   tflint --init && tflint --recursive
config {
  # Also lint the modules called by each environment.
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS rules: invalid instance types, deprecated arguments, naming limits...
plugin "aws" {
  enabled = true
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
