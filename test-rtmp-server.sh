#!/bin/bash
# Test RTMP Server Setup

SERVER_IP="3.230.37.216"
KEY_PATH="$HOME/Downloads/mac25.pem"

echo "🧪 Testing RTMP Server Setup"
echo "================================"
echo ""

echo "1️⃣ Testing HTTP connection..."
if curl -s -I --connect-timeout 5 "http://$SERVER_IP/" > /dev/null 2>&1; then
    echo "✅ HTTP is accessible"
else
    echo "❌ HTTP not accessible (Nginx may not be running yet)"
    echo ""
    echo "Connecting to server to check logs..."
    
    # Try to SSH without config file
    ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o IdentitiesOnly=yes \
        -F /dev/null \
        ubuntu@$SERVER_IP << 'EOSSH'
echo ""
echo "📊 Checking cloud-init status..."
cloud-init status

echo ""
echo "📊 Checking Nginx status..."
sudo systemctl status nginx --no-pager || echo "Nginx not running"

echo ""
echo "📋 Last 30 lines of cloud-init log..."
sudo tail -30 /var/log/cloud-init-output.log

echo ""
echo "🔧 Checking if Nginx is installed..."
which nginx || echo "Nginx not installed"

echo ""
echo "📦 Checking package installation..."
dpkg -l | grep nginx || echo "No nginx packages found"
EOSSH
    
    exit 1
fi

echo ""
echo "2️⃣ Testing HLS endpoint..."
if curl -s -I --connect-timeout 5 "http://$SERVER_IP/hls/" | grep -q "200\|403\|404"; then
    echo "✅ HLS endpoint responding"
else
    echo "❌ HLS endpoint not responding"
fi

echo ""
echo "3️⃣ Testing RTMP port..."
if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$SERVER_IP/1935" 2>/dev/null; then
    echo "✅ RTMP port 1935 is open"
else
    echo "❌ RTMP port 1935 not accessible"
fi

echo ""
echo "================================"
echo "📝 Summary:"
echo "   RTMP Ingest URL: rtmp://$SERVER_IP/live/ogulcan"
echo "   HLS Playback: http://$SERVER_IP/hls/ogulcan.m3u8"
echo "   Web Player: https://live.ogulcanaydogan.com"
