#!/bin/bash
# Create a test stream to verify the RTMP server works

SERVER_IP="3.230.37.216"
RTMP_URL="rtmp://$SERVER_IP/live/ogulcan"
HLS_URL="http://$SERVER_IP/hls/ogulcan.m3u8"

echo "🎬 Creating Test Stream"
echo "======================"
echo ""
echo "This will stream a test pattern for 30 seconds"
echo "Open https://live.ogulcanaydogan.com in your browser"
echo "and paste this URL: $HLS_URL"
echo ""
echo "Starting in 5 seconds..."
sleep 5

# Generate a test pattern and stream it
ffmpeg -f lavfi -i testsrc=size=1280x720:rate=30 \
       -f lavfi -i sine=frequency=1000:sample_rate=48000 \
       -c:v libx264 -preset veryfast -tune zerolatency \
       -b:v 2500k -maxrate 2500k -bufsize 5000k \
       -pix_fmt yuv420p -g 60 -c:a aac -b:a 128k -ar 48000 \
       -f flv "$RTMP_URL" \
       -t 30 \
       2>&1 | grep -E "frame=|error|Failed"

echo ""
echo "✅ Test stream complete!"
echo ""
echo "If you saw frames being sent, the server is working!"
echo "The HLS playlist should be available at: $HLS_URL"
