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

# RTMP Server Variables
variable "deploy_rtmp_server" {
  description = "Whether to deploy the RTMP ingest server"
  type        = bool
  default     = false
}

variable "ami_id" {
  description = "AMI ID for the RTMP server (Ubuntu 22.04 or Amazon Linux 2023)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS in us-east-1
}

variable "instance_type" {
  description = "EC2 instance type for RTMP server"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = ""
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the RTMP server"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}
