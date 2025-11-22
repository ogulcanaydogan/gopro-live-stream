#!/bin/bash

CERT_ARN="arn:aws:acm:us-east-1:211125457564:certificate/5015a7f0-020c-4d98-84cc-58f1c163fbf6"

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
