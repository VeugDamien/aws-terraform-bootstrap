# State of this environment, in the bucket created by bootstrap/bootstrap.yaml.
# Copy the stack outputs StateBucketName, StateKey and Region.
terraform {
  backend "s3" {
    bucket       = "my-app-dev-tfstate-000000000000"
    key          = "my-app/dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
