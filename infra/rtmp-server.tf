# RTMP Server Infrastructure (Optional)
# Set deploy_rtmp_server = true to enable

# Security group for RTMP server
resource "aws_security_group" "rtmp_server" {
  count       = var.deploy_rtmp_server ? 1 : 0
  name        = "gopro-rtmp-server-sg"
  description = "Security group for GoPro RTMP ingest server"

  # RTMP ingress (from GoPro Quik app)
  # Restrict this to your IP range for security
  ingress {
    from_port   = 1935
    to_port     = 1935
    protocol    = "tcp"
    cidr_blocks = var.rtmp_cidr_blocks
    description = "RTMP streaming - restrict to trusted IPs in production"
  }

  # HTTP for HLS delivery
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP HLS delivery"
  }

  # HTTPS (optional)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  # SSH for management
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
    description = "SSH access"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "gopro-rtmp-server"
    Project = "gopro-live-stream"
  }
}

# EC2 instance for RTMP server
resource "aws_instance" "rtmp_server" {
  count         = var.deploy_rtmp_server ? 1 : 0
  ami           = var.ami_id # Ubuntu 22.04 LTS or Amazon Linux 2023
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.rtmp_server[0].id]
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              exec > >(tee /var/log/user-data.log)
              exec 2>&1
              
              echo "Starting RTMP server setup..."
              
              # Update system
              apt-get update
              
              # Install Nginx with RTMP module
              apt-get install -y nginx libnginx-mod-rtmp
              
              # Create HLS directory
              mkdir -p /var/www/hls
              chown -R www-data:www-data /var/www/hls
              chmod -R 755 /var/www/hls
              
              # Configure Nginx with RTMP and load module properly
              cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
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

        # Main application - anyone can publish (less secure, for testing)
        # Use a hard-to-guess stream key for basic security
        application live {
            live on;
            record off;

            # Enable HLS
            hls on;
            hls_path /var/www/hls;
            hls_fragment 2s;
            hls_playlist_length 10s;

            # Security: Only allow localhost or trusted IPs to publish
            # For full security, restrict the security group or use RTMPS
            allow publish all;
            allow play all;

            # Drop idle streams after 30s
            drop_idle_publisher 30s;
        }
    }
}

# HTTP configuration
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    server {
        listen 80;
        server_name _;
        
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
NGINX_EOF
              
              # Test and start Nginx
              nginx -t
              systemctl enable nginx
              systemctl restart nginx
              
              # Install Certbot for SSL
              echo "Installing Certbot..."
              snap install --classic certbot
              ln -sf /snap/bin/certbot /usr/bin/certbot
              
              # Wait for DNS to propagate (60 seconds)
              echo "Waiting for DNS propagation..."
              sleep 60
              
              # Get SSL certificate
              echo "Requesting SSL certificate..."
              certbot certonly --nginx \
                -d ${var.rtmp_domain_name} \
                --non-interactive \
                --agree-tos \
                -m ${var.admin_email} \
                --redirect || echo "SSL cert failed, will retry manually"

              # Enable automatic certificate renewal
              systemctl enable certbot.timer
              systemctl start certbot.timer
              
              # Update Nginx config for HTTPS (only if cert was successful)
              if [ -f /etc/letsencrypt/live/${var.rtmp_domain_name}/fullchain.pem ]; then
                echo "Configuring HTTPS..."
                cat > /etc/nginx/nginx.conf << 'NGINX_HTTPS_EOF'
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
            drop_idle_publisher 30s;
        }
    }
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name ${var.rtmp_domain_name};
        return 301 https://$host$request_uri;
    }
    
    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name ${var.rtmp_domain_name};

        ssl_certificate /etc/letsencrypt/live/${var.rtmp_domain_name}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${var.rtmp_domain_name}/privkey.pem;

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
NGINX_HTTPS_EOF
                systemctl restart nginx
                echo "HTTPS configured successfully!"
              else
                echo "SSL certificate not obtained, running HTTP only"
              fi
              
              echo "RTMP server setup complete!" > /var/log/rtmp-setup-complete.log
              echo "Setup finished at $(date)" >> /var/log/rtmp-setup-complete.log
              EOF

  tags = {
    Name    = "gopro-rtmp-server"
    Project = "gopro-live-stream"
  }
}

# Route53 DNS record that auto-updates to EC2's IP
# This eliminates the need for Elastic IP (saves ~$3.60/month)
resource "aws_route53_record" "rtmp_server" {
  count   = var.deploy_rtmp_server ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.rtmp_domain_name
  type    = "A"
  ttl     = 300 # 5 minute TTL balances update speed and DNS query costs
  records = [aws_instance.rtmp_server[0].public_ip]
}

output "rtmp_server_ip" {
  description = "Public IP of the RTMP server (changes each deployment)"
  value       = var.deploy_rtmp_server ? aws_instance.rtmp_server[0].public_ip : null
}

output "rtmp_server_domain" {
  description = "Domain name for RTMP server (stable across deployments)"
  value       = var.rtmp_domain_name
}

output "rtmp_ingest_url" {
  description = "RTMP URL to use in GoPro Quik app (use domain for stability)"
  value       = var.rtmp_domain_name != "" ? "rtmp://${var.rtmp_domain_name}/live/${var.rtmp_stream_key}" : (var.deploy_rtmp_server ? "rtmp://${aws_instance.rtmp_server[0].public_ip}/live/${var.rtmp_stream_key}" : null)
  sensitive   = true
}

output "hls_playback_url" {
  description = "HLS URL to paste in the web player (use domain for stability)"
  value       = var.rtmp_domain_name != "" ? "https://${var.rtmp_domain_name}/hls/${var.rtmp_stream_key}.m3u8" : (var.deploy_rtmp_server ? "http://${aws_instance.rtmp_server[0].public_ip}/hls/${var.rtmp_stream_key}.m3u8" : null)
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to access the server"
  value       = var.deploy_rtmp_server && var.key_name != "" ? "ssh -i ${var.key_name}.pem ubuntu@${var.rtmp_domain_name != "" ? var.rtmp_domain_name : aws_instance.rtmp_server[0].public_ip}" : null
}
