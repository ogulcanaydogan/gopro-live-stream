#!/bin/bash
# Nginx-RTMP Setup Script for Ubuntu/Amazon Linux
# This sets up an RTMP ingest server that outputs HLS

set -e

echo "Installing Nginx with RTMP module..."

# Update system
sudo apt-get update || sudo yum update -y

# Install dependencies
if command -v apt-get &> /dev/null; then
    # Ubuntu/Debian
    sudo apt-get install -y nginx libnginx-mod-rtmp
else
    # Amazon Linux / RHEL
    sudo yum install -y epel-release
    sudo yum install -y nginx nginx-mod-rtmp
fi

# Create HLS directory
sudo mkdir -p /var/www/hls
sudo chown -R nginx:nginx /var/www/hls || sudo chown -R www-data:www-data /var/www/hls

# Backup existing nginx config
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# Create Nginx config with RTMP and HLS
cat > /tmp/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

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

# Apply config
sudo cp /tmp/nginx.conf /etc/nginx/nginx.conf

# Test configuration
sudo nginx -t

# Start and enable Nginx
sudo systemctl enable nginx
sudo systemctl restart nginx

# Open firewall ports
if command -v ufw &> /dev/null; then
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 1935/tcp
fi

echo ""
echo "✅ Nginx-RTMP server is ready!"
echo ""
echo "📡 RTMP Ingest URL: rtmp://YOUR_SERVER_IP/live/ogulcan"
echo "🎥 HLS Playback URL: http://YOUR_SERVER_IP/hls/ogulcan.m3u8"
echo ""
echo "Next steps:"
echo "1. Note your server's public IP address"
echo "2. Open GoPro Quik app on iPhone"
echo "3. Go to Live → RTMP → Custom"
echo "4. Enter: rtmp://YOUR_SERVER_IP/live/ogulcan"
echo "5. Start streaming from GoPro"
echo "6. Visit https://live.ogulcanaydogan.com"
echo "7. Paste HLS URL: http://YOUR_SERVER_IP/hls/ogulcan.m3u8"
echo ""
