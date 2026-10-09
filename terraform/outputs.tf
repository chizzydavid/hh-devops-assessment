output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "ECR Repository URL for container image tagging and pushing"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_ci.arn
  description = "IAM Role ARN to configure in GitHub Secrets (AWS_ROLE_ARN)"
}

output "tf_state_bucket_name" {
  value       = module.s3_bucket.bucket_id
  description = "Name of the S3 bucket created for Terraform remote state"
}
