# GoPro Live Streaming Setup Guide

Your web player is live at **https://live.ogulcanaydogan.com** ✅

Now you need to set up an RTMP server to receive streams from your GoPro.

## Architecture

```
GoPro Camera → iPhone (GoPro Quik) → RTMP Server → HLS → CloudFront → Viewers
```

## Option 1: Deploy RTMP Server on AWS (Recommended)

### Prerequisites
1. AWS CLI configured
2. An EC2 key pair for SSH access (or create one):
   ```bash
   aws ec2 create-key-pair --key-name gopro-livestream \
     --query 'KeyMaterial' --output text > ~/.ssh/gopro-livestream.pem
   chmod 400 ~/.ssh/gopro-livestream.pem
   ```

### Step 1: Update Terraform Variables

Edit `infra/terraform.tfvars` and add:
```hcl
# Existing variables
bucket_name           = "live.ogulcanaydogan.com"
domain_name           = "live.ogulcanaydogan.com"
acm_certificate_arn   = "arn:aws:acm:us-east-1:211125457564:certificate/5015a7f0-020c-4d98-84cc-58f1c163fbf6"
environment           = "prod"

# RTMP Server (add these lines)
deploy_rtmp_server    = true
key_name              = "gopro-livestream"  # Your EC2 key pair name
instance_type         = "t3.small"          # ~$15/month, good for 1080p streaming
ssh_cidr_blocks       = ["YOUR_IP/32"]      # Replace with your IP for security
```

To get your IP: `curl -s https://checkip.amazonaws.com`

### Step 2: Deploy the RTMP Server
```bash
cd infra
terraform init
terraform apply
```

After successful apply, note the outputs:
- `rtmp_ingest_url` - Use this in GoPro Quik app
- `hls_playback_url` - Paste this in your web player
- `rtmp_server_ip` - Public IP of your server
- `ssh_command` - Connect to debug if needed

### Step 3: Configure GoPro Quik App (iPhone)

1. Open **GoPro Quik** app on your iPhone
2. Connect your GoPro camera to iPhone
3. Tap **Live** icon
4. Select **RTMP**
5. Choose **Custom** (not Facebook/YouTube)
6. Enter the **RTMP URL** from Terraform output:
   ```
   rtmp://YOUR_SERVER_IP/live/ogulcan
   ```
7. Tap **Save**

### Step 4: Start Streaming

1. On GoPro Quik: Tap **Go Live**
2. Wait 5-10 seconds for HLS fragments to generate
3. Visit **https://live.ogulcanaydogan.com**
4. Paste the **HLS URL** from Terraform output:
   ```
   http://YOUR_SERVER_IP/hls/ogulcan.m3u8
   ```
5. Click **Start Stream**

## Option 2: Manual Setup on Any Server

If you prefer to use an existing server or a different cloud provider (DigitalOcean, Linode, etc.):

### Step 1: Run Setup Script
```bash
# Copy the script to your server
scp setup-rtmp-server.sh user@your-server-ip:~

# SSH to server and run it
ssh user@your-server-ip
chmod +x setup-rtmp-server.sh
sudo ./setup-rtmp-server.sh
```

### Step 2: Open Firewall Ports
```bash
# Ubuntu/Debian with UFW
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 1935/tcp

# Or manually configure your cloud provider's firewall
```

### Step 3: Get Server IP
```bash
curl -s https://checkip.amazonaws.com
# or
hostname -I | awk '{print $1}'
```

### Step 4: Use URLs
- **RTMP Ingest (GoPro Quik):** `rtmp://YOUR_SERVER_IP/live/ogulcan`
- **HLS Playback (Web Player):** `http://YOUR_SERVER_IP/hls/ogulcan.m3u8`

## Option 3: Use Third-Party Service

You can also use a managed streaming service:
- **AWS IVS (Interactive Video Service)** - Easy, pay-as-you-go
- **Mux** - Developer-friendly with good APIs
- **Cloudflare Stream** - Part of Cloudflare ecosystem

These services provide RTMP endpoints and HLS URLs directly.

## Troubleshooting

### GoPro won't connect to RTMP server
- Verify ports 1935 is open: `sudo netstat -tlnp | grep 1935`
- Check Nginx is running: `sudo systemctl status nginx`
- View Nginx logs: `sudo tail -f /var/log/nginx/error.log`

### Web player says "Offline"
- Ensure you're streaming from GoPro first
- Wait 10-15 seconds for HLS fragments
- Check HLS directory: `ls -lh /var/www/hls/`
- Test HLS URL directly: `curl -I http://YOUR_IP/hls/ogulcan.m3u8`

### Stream is laggy
- Reduce `hls_fragment` to 1s in nginx.conf (lower latency, more requests)
- Use a larger instance type (t3.medium instead of t3.small)
- Move server closer to your physical location

### Can't SSH to server
- Verify key permissions: `chmod 400 ~/.ssh/gopro-livestream.pem`
- Check security group allows your IP on port 22
- Use AWS Systems Manager Session Manager as alternative

## Monitoring & Maintenance

### Check RTMP Stats
Visit: `http://YOUR_SERVER_IP/stat`

### View Live Logs
```bash
ssh -i ~/.ssh/gopro-livestream.pem ubuntu@YOUR_SERVER_IP
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Restart Nginx
```bash
sudo systemctl restart nginx
```

## Costs (AWS Option)

- **t3.small EC2:** ~$15/month
- **Elastic IP:** Free while attached
- **Data transfer:** ~$0.09/GB (first 10TB)
- **CloudFront:** Already deployed

For 24/7 streaming at 4Mbps: ~$400/month in data transfer
For 2-3 hours/week: ~$20/month total

## Next Steps

Once streaming works:
1. Add HTTPS to RTMP server with Let's Encrypt
2. Set up a subdomain (e.g., `stream.ogulcanaydogan.com`)
3. Enable CloudWatch monitoring
4. Configure automatic Nginx restarts
5. Add basic auth to protect your stream

---

**Need help?** Check the logs or reach out!
