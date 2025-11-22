#!/bin/bash
# Fix Nginx RTMP configuration on the server

SERVER_IP="3.230.37.216"
KEY_PATH="$HOME/Downloads/mac25.pem"

echo "🔧 Fixing Nginx RTMP Configuration..."
echo ""

ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o IdentitiesOnly=yes \
    -F /dev/null \
    ubuntu@$SERVER_IP << 'EOSSH'

# Create proper Nginx config
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user www-data;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load RTMP module
load_module /usr/lib/nginx/modules/ngx_rtmp_module.so;

events {
    worker_connections 1024;
}

# RTMP configuration
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        
        application live {
            live on;
            record off;
            
            # Enable HLS
            hls on;
            hls_path /var/www/hls;
            hls_fragment 2s;
            hls_playlist_length 10s;
            
            # Allow publishing from anywhere (restrict in production!)
            allow publish all;
            allow play all;
        }
    }
}

# HTTP configuration
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Enable CORS for HLS
    server {
        listen 80;
        server_name _;
        
        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            
            root /var/www;
            
            # CORS headers
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'Range' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
            
            # Disable cache for live streaming
            add_header Cache-Control no-cache always;
            
            # Handle preflight requests
            if ($request_method = 'OPTIONS') {
                return 204;
            }
        }
        
        # Optional: status page
        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }
        
        location /stat.xsl {
            root /usr/share/nginx/html;
        }
    }
}
EOF

# Create HLS directory
sudo mkdir -p /var/www/hls
sudo chown -R www-data:www-data /var/www/hls
sudo chmod 755 /var/www/hls

# Test configuration
echo ""
echo "Testing Nginx configuration..."
sudo nginx -t

# Restart Nginx
echo ""
echo "Restarting Nginx..."
sudo systemctl restart nginx

# Check status
echo ""
echo "Nginx status:"
sudo systemctl status nginx --no-pager -l | head -10

echo ""
echo "✅ Configuration applied!"
EOSSH

echo ""
echo "🧪 Testing again..."
sleep 3

if curl -s -I "http://$SERVER_IP/" | grep -q "200\|404"; then
    echo "✅ HTTP is now accessible!"
else
    echo "❌ Still having issues"
    exit 1
fi

if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$SERVER_IP/1935" 2>/dev/null; then
    echo "✅ RTMP port 1935 is open!"
else
    echo "❌ RTMP port not accessible"
fi

echo ""
echo "================================"
echo "🎉 Server is ready for testing!"
echo ""
echo "📝 URLs:"
echo "   RTMP Ingest: rtmp://$SERVER_IP/live/ogulcan"
echo "   HLS Playback: http://$SERVER_IP/hls/ogulcan.m3u8"
echo "   Web Player: https://live.ogulcanaydogan.com"
echo ""
echo "📱 Next steps:"
echo "   1. We can use FFmpeg to create a test stream"
echo "   2. Or you can use your GoPro with the RTMP URL above"
