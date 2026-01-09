#!/bin/bash
# Check ACM certificate status
# Usage: ./check-cert-status.sh [CERT_ARN]
#   or set ACM_CERT_ARN environment variable

CERT_ARN="${1:-${ACM_CERT_ARN:-}}"

if [ -z "$CERT_ARN" ]; then
    echo "Usage: ./check-cert-status.sh <certificate-arn>"
    echo "  or set ACM_CERT_ARN environment variable"
    exit 1
fi

echo "Monitoring ACM certificate status..."
echo "Press Ctrl+C to stop"
echo ""

while true; do
    STATUS=$(aws acm describe-certificate \
        --certificate-arn "$CERT_ARN" \
        --region us-east-1 \
        --query 'Certificate.Status' \
        --output text)
    
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    
    if [ "$STATUS" = "ISSUED" ]; then
        echo "[$TIMESTAMP] ✅ Certificate Status: $STATUS"
        echo ""
        echo "🎉 Certificate is now ISSUED! You can proceed with terraform apply."
        break
    else
        echo "[$TIMESTAMP] ⏳ Certificate Status: $STATUS"
    fi
    
    sleep 30
done
