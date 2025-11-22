#!/bin/bash
# Setup HTTPS with Let's Encrypt for RTMP server

set -e

echo "🔒 Setting up HTTPS with Let's Encrypt..."
echo ""

# Install Certbot
echo "📦 Installing Certbot..."
sudo apt-get update -qq
sudo apt-get install -y certbot python3-certbot-nginx

# Stop Nginx temporarily
echo "⏸️  Stopping Nginx..."
sudo systemctl stop nginx

# Get certificate
echo "🔐 Requesting SSL certificate..."
sudo certbot certonly --standalone \
  -d stream.ogulcanaydogan.com \
  --non-interactive \
  --agree-tos \
  --email ogulcan@ogulcanaydogan.com \
  --http-01-port 80

# Update Nginx config with HTTPS
echo "⚙️  Updating Nginx configuration..."
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
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name stream.ogulcanaydogan.com;
        
        location /.well-known/acme-challenge/ {
            root /var/www/html;
        }
        
        location / {
            return 301 https://$server_name$request_uri;
        }
    }
    
    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name stream.ogulcanaydogan.com;
        
        ssl_certificate /etc/letsencrypt/live/stream.ogulcanaydogan.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/stream.ogulcanaydogan.com/privkey.pem;
        
        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        
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
            
            if ($request_method = 'OPTIONS') {
                return 204;
            }
        }
        
        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }
        
        location /stat.xsl {
            root /usr/share/nginx/html;
        }
        
        location / {
            root /var/www/html;
            index index.html;
        }
    }
}
EOF

# Create web root for certbot renewals
sudo mkdir -p /var/www/html

# Test configuration
echo ""
echo "🧪 Testing Nginx configuration..."
sudo nginx -t

# Start Nginx
echo "▶️  Starting Nginx..."
sudo systemctl start nginx

# Setup auto-renewal
echo "🔄 Setting up certificate auto-renewal..."
sudo systemctl enable certbot.timer

echo ""
echo "✅ HTTPS setup complete!"
echo ""
echo "📝 New URLs:"
echo "   RTMP Ingest: rtmp://stream.ogulcanaydogan.com/live/ogulcan"
echo "   HLS Playback (HTTPS): https://stream.ogulcanaydogan.com/hls/ogulcan.m3u8"
echo "   Stats: https://stream.ogulcanaydogan.com/stat"
echo ""
echo "🌐 You can now use the web player at https://live.ogulcanaydogan.com"
echo "   and paste: https://stream.ogulcanaydogan.com/hls/ogulcan.m3u8"
EOF

chmod +x setup-https.sh
echo "✅ Script created!"
