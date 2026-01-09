#!/bin/bash
# GoPro Live Stream - Server Startup Script
# This script starts the RTMP server and configures SSL automatically

set -e

# Configuration - customize these for your environment
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/gopro-rtmp.pem}"
RTMP_DOMAIN="${RTMP_DOMAIN:-stream.ogulcanaydogan.com}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@ogulcanaydogan.com}"
STREAM_KEY="${STREAM_KEY:-gopro}"

echo "🚀 Starting RTMP server..."
echo "   SSH Key: $SSH_KEY_PATH"
echo "   Domain:  $RTMP_DOMAIN"
echo ""

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "❌ SSH key not found at: $SSH_KEY_PATH"
    echo "   Set SSH_KEY_PATH environment variable to your key location"
    echo "   Example: SSH_KEY_PATH=~/Downloads/mac25.pem ./start-server.sh"
    exit 1
fi

cd "$(dirname "$0")/infra"

# Start the server
terraform apply -var="deploy_rtmp_server=true" -auto-approve

# Get the server IP
SERVER_IP=$(terraform output -raw rtmp_server_ip)
echo ""
echo "✅ Server started at IP: $SERVER_IP"
echo "📡 DNS: $RTMP_DOMAIN"
echo ""
echo "⏳ Waiting for server initialization..."

# Wait for server to be reachable
MAX_WAIT=300  # 5 minutes max
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if ssh -i "$SSH_KEY_PATH" \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o ConnectTimeout=5 \
           -F /dev/null \
           ubuntu@${SERVER_IP} 'exit' 2>/dev/null; then
        echo "✅ Server is reachable"
        break
    fi
    echo "   Waiting for SSH... (${ELAPSED}s)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "❌ Server not reachable after ${MAX_WAIT}s"
    exit 1
fi

# Wait for Nginx to be installed by user_data script
echo "⏳ Waiting for Nginx installation..."
MAX_WAIT=300  # 5 minutes max
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if ssh -i "$SSH_KEY_PATH" \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -F /dev/null \
           ubuntu@${SERVER_IP} 'which nginx' 2>/dev/null | grep -q nginx; then
        echo "✅ Nginx is installed"
        break
    fi
    echo "   Waiting for Nginx installation... (${ELAPSED}s)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "❌ Nginx not installed after ${MAX_WAIT}s"
    exit 1
fi

# Wait a bit more for DNS propagation
echo "⏳ Waiting 60s for DNS propagation..."
sleep 60

echo ""
echo "🔐 Configuring SSL certificate..."

# Configure SSL using IP (avoids SSH config issues)
ssh -i "$SSH_KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -F /dev/null \
    ubuntu@${SERVER_IP} << 'ENDSSH'
# First, create HTTP-only config
sudo tee /etc/nginx/nginx.conf > /dev/null << 'HTTPEOF'
user www-data;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

load_module /usr/lib/nginx/modules/ngx_rtmp_module.so;

events {
    worker_connections 1024;
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        application live {
            live on;
            record off;
            hls on;
            hls_path /var/www/hls;
            hls_fragment 2s;
            hls_playlist_length 10s;
            allow publish all;
            allow play all;
        }
    }
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    server {
        listen 80;
        server_name stream.ogulcanaydogan.com;
        
        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /var/www;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Access-Control-Allow-Origin *;
        }
        
        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }
        
        location /stat.xsl {
            root /usr/share/nginx/html;
        }
    }
}
HTTPEOF

sudo systemctl restart nginx
echo "✅ HTTP config ready"

# Install certbot
echo "📦 Installing certbot..."
sudo snap install --classic certbot 2>/dev/null || echo "Certbot already installed"
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Get SSL certificate
echo "🔐 Obtaining SSL certificate..."
sudo certbot certonly --nginx \
    -d stream.ogulcanaydogan.com \
    --non-interactive \
    --agree-tos \
    -m admin@ogulcanaydogan.com

# Update Nginx config for HTTPS
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user www-data;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

load_module /usr/lib/nginx/modules/ngx_rtmp_module.so;

events {
    worker_connections 1024;
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        application live {
            live on;
            record off;
            hls on;
            hls_path /var/www/hls;
            hls_fragment 2s;
            hls_playlist_length 10s;
            allow publish all;
            allow play all;
        }
    }
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    server {
        listen 80;
        server_name _;
        return 301 https://\$host\$request_uri;
    }
    
    server {
        listen 443 ssl http2;
        server_name stream.ogulcanaydogan.com;

        ssl_certificate /etc/letsencrypt/live/stream.ogulcanaydogan.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/stream.ogulcanaydogan.com/privkey.pem;

        # SSL Security Settings
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:10m;

        # Security Headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /var/www;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Access-Control-Allow-Origin *;
        }
        
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

# Enable automatic certificate renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
echo "✅ Certbot auto-renewal enabled"

# Restart Nginx with HTTPS config
sudo systemctl restart nginx
echo "✅ SSL configured successfully!"
ENDSSH

echo ""
echo "✅ Server is ready!"
echo ""
echo "📋 Your URLs:"
echo "   RTMP: rtmp://$RTMP_DOMAIN/live/$STREAM_KEY"
echo "   HLS:  https://$RTMP_DOMAIN/hls/$STREAM_KEY.m3u8"
echo ""
echo "🎥 Ready to stream from your GoPro!"
