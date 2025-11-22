bucket_name           = "live.ogulcanaydogan.com"
domain_name           = "live.ogulcanaydogan.com"
acm_certificate_arn   = "arn:aws:acm:us-east-1:211125457564:certificate/5015a7f0-020c-4d98-84cc-58f1c163fbf6"
environment           = "prod"

# RTMP Server Configuration
deploy_rtmp_server    = true
key_name              = "mac25"
instance_type         = "t3.small"
ssh_cidr_blocks       = ["194.72.43.234/32"]
