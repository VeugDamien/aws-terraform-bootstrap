output "account_id" {
  description = "AWS account the environment runs in."
  value       = data.aws_caller_identity.current.account_id
}

output "environment" {
  description = "Environment this module was deployed for."
  value       = var.environment
}
