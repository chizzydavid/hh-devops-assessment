variable "bucket_name" {
  type        = string
  description = "Unique name for the S3 state bucket"
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Allow destroying bucket with contents"
}

variable "versioning_status" {
  type        = string
  default     = "Enabled"
  description = "Versioning state for the bucket (Enabled, Disabled, or Suspended)"

  validation {
    condition     = contains(["Enabled", "Disabled", "Suspended"], var.versioning_status)
    error_message = "The versioning_status variable must be one of: Enabled, Disabled, or Suspended."
  }
}
