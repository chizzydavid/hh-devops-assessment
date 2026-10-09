variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Deployment environment"
}

variable "service_name" {
  type        = string
  default     = "hh-demo-api"
  description = "Name of the service and ECR repository"
}

variable "github_repo" {
  type        = string
  default     = "your-org/hh-demo-api"
  description = "GitHub repository in org/repo format for OIDC trust relationship"
}
