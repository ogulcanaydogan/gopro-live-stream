# RTMP Server Infrastructure (Optional)
# Set deploy_rtmp_server = true to enable

# Security group for RTMP server
resource "aws_security_group" "rtmp_server" {
  count       = var.deploy_rtmp_server ? 1 : 0
  name        = "gopro-rtmp-server-sg"
  description = "Security group for GoPro RTMP ingest server"

  # RTMP ingress (from GoPro Quik app)
  ingress {
    from_port   = 1935
    to_port     = 1935
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "RTMP streaming"
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
              
              # Update system
              apt-get update || yum update -y
              
              # Install Nginx with RTMP module
              if command -v apt-get &> /dev/null; then
                  apt-get install -y nginx libnginx-mod-rtmp
                  NGINX_USER="www-data"
              else
                  yum install -y epel-release
                  yum install -y nginx nginx-mod-rtmp
                  NGINX_USER="nginx"
              fi
              
              # Create HLS directory
              mkdir -p /var/www/hls
              chown -R $NGINX_USER:$NGINX_USER /var/www/hls
              
              # Configure Nginx with RTMP
              cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
              user www-data;
              worker_processes auto;
              error_log /var/log/nginx/error.log;
              pid /run/nginx.pid;
              
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
                  sendfile on;
                  keepalive_timeout 65;
                  
                  server {
                      listen 80;
                      server_name _;
                      
                      location /hls {
                          types {
                              application/vnd.apple.mpegurl m3u8;
                              video/mp2t ts;
                          }
                          root /var/www;
                          add_header 'Access-Control-Allow-Origin' '*' always;
                          add_header Cache-Control no-cache always;
                      }
                      
                      location /stat {
                          rtmp_stat all;
                          rtmp_stat_stylesheet stat.xsl;
                      }
                  }
              }
              NGINX_EOF
              
              # Start Nginx
              systemctl enable nginx
              systemctl restart nginx
              
              echo "RTMP server setup complete!" > /var/log/rtmp-setup.log
              EOF

  tags = {
    Name    = "gopro-rtmp-server"
    Project = "gopro-live-stream"
  }
}

# Elastic IP for stable public IP
resource "aws_eip" "rtmp_server" {
  count    = var.deploy_rtmp_server ? 1 : 0
  instance = aws_instance.rtmp_server[0].id
  domain   = "vpc"

  tags = {
    Name    = "gopro-rtmp-server-eip"
    Project = "gopro-live-stream"
  }
}

output "rtmp_server_ip" {
  description = "Public IP of the RTMP server"
  value       = var.deploy_rtmp_server ? aws_eip.rtmp_server[0].public_ip : null
}

output "rtmp_ingest_url" {
  description = "RTMP URL to use in GoPro Quik app"
  value       = var.deploy_rtmp_server ? "rtmp://${aws_eip.rtmp_server[0].public_ip}/live/ogulcan" : null
}

output "hls_playback_url" {
  description = "HLS URL to paste in the web player"
  value       = var.deploy_rtmp_server ? "http://${aws_eip.rtmp_server[0].public_ip}/hls/ogulcan.m3u8" : null
}

output "ssh_command" {
  description = "SSH command to access the server"
  value       = var.deploy_rtmp_server && var.key_name != "" ? "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.rtmp_server[0].public_ip}" : null
}
