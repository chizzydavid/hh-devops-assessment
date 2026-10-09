variable "repository_name" {
  type        = string
  description = "ECR repository name"
}

variable "untagged_image_retention_days" {
  type        = number
  default     = 7
  description = "Days before deleting untagged images"
}

variable "max_tagged_image_count" {
  type        = number
  default     = 30
  description = "Maximum number of tagged images to retain"
}
