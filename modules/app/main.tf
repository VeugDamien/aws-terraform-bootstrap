# Code shared by every environment. Put your resources here (or split them
# into several modules) and pass the per-environment values as variables.
#
# The data source below costs nothing: it lets the first apply prove that the
# whole chain works (OIDC, role, state). Replace it with your own resources.
data "aws_caller_identity" "current" {}
