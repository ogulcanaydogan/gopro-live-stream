#!/bin/bash
# GoPro Live Stream - Server Shutdown Script
# This script stops the RTMP server to save costs

set -e

echo "🛑 Stopping RTMP server..."
cd "$(dirname "$0")/infra"

terraform apply -var="deploy_rtmp_server=false" -auto-approve

echo ""
echo "✅ Server stopped successfully!"
echo "💰 No charges until you start it again"
