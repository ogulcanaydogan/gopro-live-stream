variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name for the S3 bucket that hosts the static site"
  type        = string
}

variable "domain_name" {
  description = "Optional custom domain (e.g., live.example.com). Leave empty to use the CloudFront domain."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for the custom domain. Required when domain_name is set."
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}

variable "mime_types" {
  description = "Override MIME types for uploaded site assets"
  type        = map(string)
  default = {
    "index.html" = "text/html"
    "styles.css" = "text/css"
  }
}
