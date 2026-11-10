# Values specific to this environment are passed to the shared module here.
module "app" {
  source = "../../modules/app"

  environment = "dev"
}
