# Credentials come from the standard AWS chain: your profile or SSO locally,
# the OIDC role in GitHub Actions. No access key anywhere.
provider "aws" {
  region = "eu-west-1"

  # Applied to every taggable resource. Replace with your company convention
  # (any keys and values, for example "my-company:cost-center").
  default_tags {
    tags = {
      Project     = "my-app"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
