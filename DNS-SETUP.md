# DNS Setup for live.ogulcanaydogan.com

## Step 1: Validate ACM Certificate

Add this CNAME record to your DNS provider (e.g., Cloudflare, Route53, GoDaddy):

**Certificate Validation Record:**
- **Name/Host:** `_d41dcfd80c592c06cfa999d47e18402b.live.ogulcanaydogan.com`
- **Type:** `CNAME`
- **Value:** `_0bbbf25fdb3416bbd0920c0bd016c3a4.jkddzztszm.acm-validations.aws.`
- **TTL:** 300 (or Auto)

⚠️ **Important:** Keep the trailing dot (`.`) at the end of the Value if your DNS provider supports it.

## Step 2: Wait for Certificate Validation

After adding the DNS record, wait for AWS to validate the certificate (usually 5-30 minutes).

Check status with:
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:211125457564:certificate/5015a7f0-020c-4d98-84cc-58f1c163fbf6 \
  --region us-east-1 \
  --query 'Certificate.Status' \
  --output text
```

Wait until it shows `ISSUED` before proceeding.

## Step 3: Apply Terraform Configuration

Once the certificate is issued, apply the Terraform changes:
```bash
cd /Users/ogulcanaydogan/Desktop/ogulcanaydogan/gopro-live-stream/infra
terraform apply
```

## Step 4: Point DNS to CloudFront

After Terraform completes, add this CNAME record:

**Site Record:**
- **Name/Host:** `live` or `live.ogulcanaydogan.com` (depending on your DNS provider)
- **Type:** `CNAME`
- **Value:** `d2tvjkdkpt986g.cloudfront.net`
- **TTL:** 300 (or Auto)

## Verification

After DNS propagates (5-60 minutes), test:
```bash
# Check DNS resolution
dig live.ogulcanaydogan.com +short

# Test HTTPS
curl -I https://live.ogulcanaydogan.com
```

---

**Current Status:**
- ✅ ACM Certificate requested
- ⏳ Waiting for DNS validation
- ⏳ Terraform configuration updated (ready to apply after certificate validation)
- ⏳ DNS record to CloudFront (add after Terraform apply)
