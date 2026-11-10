# Credentials come from the standard AWS chain: your profile or SSO locally,
# the OIDC role in GitHub Actions. No access key anywhere.
provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project     = "my-app"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
