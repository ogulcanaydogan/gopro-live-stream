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

        # WebSocket chat proxy
        location /chat {
            proxy_pass http://127.0.0.1:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_read_timeout 86400;
        }
    }
}
EOF

# Install Node.js and setup chat server
echo "💬 Setting up chat server..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - > /dev/null 2>&1
sudo apt-get install -y nodejs > /dev/null 2>&1

# Create chat server
sudo mkdir -p /opt/chat
sudo tee /opt/chat/server.js > /dev/null << 'CHATEOF'
const http = require('http');
const crypto = require('crypto');

const server = http.createServer();
const clients = new Map(); // room -> Set of sockets
const recentMessages = new Map(); // room -> array of last 50 messages

function broadcast(room, message, excludeSocket = null) {
  const roomClients = clients.get(room);
  if (!roomClients) return;
  const data = JSON.stringify(message);
  for (const client of roomClients) {
    if (client !== excludeSocket && client.readyState === 1) {
      client.send(data);
    }
  }
}

server.on('upgrade', (req, socket) => {
  const url = new URL(req.url, 'http://localhost');
  const room = url.searchParams.get('room') || 'default';

  // WebSocket handshake
  const key = req.headers['sec-websocket-key'];
  const accept = crypto.createHash('sha1')
    .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
    .digest('base64');

  socket.write([
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    `Sec-WebSocket-Accept: ${accept}`,
    '', ''
  ].join('\r\n'));

  socket.readyState = 1;
  socket.room = room;

  // Add to room
  if (!clients.has(room)) clients.set(room, new Set());
  clients.get(room).add(socket);

  // Send recent messages
  const recent = recentMessages.get(room) || [];
  for (const msg of recent) {
    socket.send(JSON.stringify(msg));
  }

  // Handle incoming messages
  socket.on('data', (buffer) => {
    try {
      // Simple WebSocket frame parsing
      const firstByte = buffer[0];
      const opcode = firstByte & 0x0f;
      if (opcode === 8) { socket.end(); return; } // Close frame
      if (opcode !== 1) return; // Only text frames

      const secondByte = buffer[1];
      const isMasked = (secondByte & 0x80) !== 0;
      let payloadLength = secondByte & 0x7f;
      let offset = 2;

      if (payloadLength === 126) {
        payloadLength = buffer.readUInt16BE(2);
        offset = 4;
      } else if (payloadLength === 127) {
        payloadLength = Number(buffer.readBigUInt64BE(2));
        offset = 10;
      }

      let payload = buffer.slice(offset + (isMasked ? 4 : 0), offset + (isMasked ? 4 : 0) + payloadLength);
      if (isMasked) {
        const mask = buffer.slice(offset, offset + 4);
        for (let i = 0; i < payload.length; i++) {
          payload[i] ^= mask[i % 4];
        }
      }

      const message = JSON.parse(payload.toString());
      if (message.type === 'chat-message' && message.text && message.name) {
        const chatMsg = {
          type: 'chat-message',
          id: crypto.randomUUID(),
          name: message.name.slice(0, 50),
          text: message.text.slice(0, 500),
          ts: new Date().toISOString(),
          room: room
        };

        // Store in recent messages
        if (!recentMessages.has(room)) recentMessages.set(room, []);
        const roomMessages = recentMessages.get(room);
        roomMessages.push(chatMsg);
        if (roomMessages.length > 50) roomMessages.shift();

        // Broadcast to all in room
        broadcast(room, chatMsg);
      }
    } catch (e) { /* ignore parse errors */ }
  });

  socket.on('close', () => {
    socket.readyState = 3;
    const roomClients = clients.get(room);
    if (roomClients) {
      roomClients.delete(socket);
      if (roomClients.size === 0) clients.delete(room);
    }
  });

  socket.on('error', () => socket.end());

  // Send helper for WebSocket frames
  socket.send = (data) => {
    const payload = Buffer.from(data);
    const frame = Buffer.alloc(2 + payload.length);
    frame[0] = 0x81; // text frame
    frame[1] = payload.length;
    payload.copy(frame, 2);
    socket.write(frame);
  };
});

server.listen(3000, '127.0.0.1', () => {
  console.log('Chat server running on port 3000');
});
CHATEOF

# Create systemd service for chat
sudo tee /etc/systemd/system/chat.service > /dev/null << 'SVCEOF'
[Unit]
Description=WebSocket Chat Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/chat
ExecStart=/usr/bin/node /opt/chat/server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable chat
sudo systemctl start chat
echo "✅ Chat server started"

# Enable automatic certificate renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
echo "✅ Certbot auto-renewal enabled"

# Restart Nginx with HTTPS config
sudo systemctl restart nginx
echo "✅ SSL configured successfully!"
ENDSSH

# Health check - verify services are running
echo ""
echo "🔍 Running health checks..."

HEALTH_OK=true

# Check HTTPS endpoint
if curl -sf --max-time 10 "https://$RTMP_DOMAIN/stat" > /dev/null 2>&1; then
    echo "   ✅ HTTPS working"
else
    echo "   ❌ HTTPS not responding"
    HEALTH_OK=false
fi

# Check RTMP port
if nc -z -w5 "$RTMP_DOMAIN" 1935 2>/dev/null; then
    echo "   ✅ RTMP port open"
else
    echo "   ❌ RTMP port not accessible"
    HEALTH_OK=false
fi

# Check chat server
if curl -sf --max-time 5 -o /dev/null -w "%{http_code}" "https://$RTMP_DOMAIN/chat" 2>/dev/null | grep -q "400\|101"; then
    echo "   ✅ Chat server running"
else
    echo "   ⚠️  Chat server may not be ready (this is OK)"
fi

if [ "$HEALTH_OK" = true ]; then
    echo ""
    echo "✅ Server is ready!"
else
    echo ""
    echo "⚠️  Server started but some checks failed. It may need a minute to fully initialize."
fi

echo ""
echo "📋 Your URLs:"
echo "   RTMP: rtmp://$RTMP_DOMAIN/live/$STREAM_KEY"
echo "   HLS:  https://$RTMP_DOMAIN/hls/$STREAM_KEY.m3u8"
echo "   Chat: wss://$RTMP_DOMAIN/chat?room=gopro"
echo ""
echo "🎥 Ready to stream from your GoPro!"
