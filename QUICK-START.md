# GoPro Live Stream - Quick Start Guide

Your personal GoPro Hero 7 Black live streaming setup with HTTPS support.

## 🎯 Your Stream URLs

**These URLs never change:**

- **Web Player (share with viewers):** https://live.ogulcanaydogan.com
- **RTMP Ingest (for GoPro):** rtmp://stream.ogulcanaydogan.com/live/ogulcan
- **HLS Stream URL:** https://stream.ogulcanaydogan.com/hls/ogulcan.m3u8
- **Stats Page:** https://stream.ogulcanaydogan.com/stat

---

## ⚙️ Configuration

**First time setup - copy the example config:**
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Environment variables for start-server.sh:**
```bash
# Set your SSH key path (defaults to ~/.ssh/gopro-rtmp.pem)
export SSH_KEY_PATH=~/Downloads/mac25.pem

# Optional: customize domain and stream key
export RTMP_DOMAIN=stream.example.com
export STREAM_KEY=your-unique-key
export ADMIN_EMAIL=you@example.com
```

---

## 🚀 How to Stream (Quick Version)

### Before Your Event:

**1. Start the RTMP server** (Friday or Saturday before Sunday stream):
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream
./start-server.sh
```
Wait ~5 minutes. The script will automatically:
- Start the EC2 server
- Configure Nginx with RTMP
- Set up SSL certificate for HTTPS
- Update DNS automatically
- Show you all URLs when ready

### On Sunday at the Pub:

**2. Connect GoPro to iPhone:**
- Turn on GoPro Hero 7 Black
- Open GoPro Quik app
- Connect via WiFi (use 5GHz)

**3. Start streaming:**
- Tap **Live** in GoPro Quik
- Select **RTMP** → **Custom**
- The URL should already be saved: `rtmp://stream.ogulcanaydogan.com/live/ogulcan`
- Tap **Go Live**
- Wait 10-15 seconds for stream to start

**4. Share with viewers:**
- Send them: https://live.ogulcanaydogan.com
- They can watch directly in their browser!

### After Streaming:

**5. Stop the server** (saves ~$15/month):
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream
./stop-server.sh
```

---

## 📱 Detailed Instructions

### First Time Setup

#### GoPro Configuration:
1. Open **GoPro Quik** app on iPhone
2. Connect your GoPro Hero 7 Black
3. Go to **Live** → **RTMP** → **Custom**
4. Enter RTMP URL: `rtmp://stream.ogulcanaydogan.com/live/ogulcan`
5. Save - you won't need to enter this again!

### Regular Streaming Workflow

#### Day Before (Friday/Saturday):
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream
./start-server.sh
```
This starts your RTMP server and configures everything automatically. Takes ~5 minutes total.

The script will:
- Create EC2 server with new IP address
- Update DNS to point stream.ogulcanaydogan.com to new IP
- Install and configure Nginx with RTMP module
- Set up Let's Encrypt SSL certificate for HTTPS
- Display all URLs when ready

#### During Your Event:
1. **Connect GoPro to iPhone** via GoPro Quik app
2. **Position your GoPro** where you want to film
3. **Open GoPro Quik** → Tap **Live** → Tap **Go Live**
4. **Share the link:** https://live.ogulcanaydogan.com

#### Viewers Can:
- Open https://live.ogulcanaydogan.com in any browser
- The stream URL is already configured
- Click **Start Stream** to watch
- Works on phones, tablets, computers

#### After Streaming:
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream
./stop-server.sh
```
This stops the server and saves money. Server will be completely destroyed (no charges).

---

## 💰 Cost Breakdown

**When Server is Running:**
- EC2 t3.small: ~$0.50/day (~$15/month if left on)
- Data transfer: ~$0.09/GB
- No Elastic IP charges (using dynamic IP with automatic DNS updates)

**When Server is Stopped:**
- $0/month - Everything is deleted (EC2, security groups)
- DNS records remain configured (no charge)
- Just run `./start-server.sh` again when needed

**Estimated Cost per Stream:**
- 3-hour stream: ~$2-3 total
- Server running 1 day: ~$0.50
- 10GB data transfer: ~$0.90

---

## 🔧 Troubleshooting

### Stream Won't Start
- **Check GoPro battery** - must be charged
- **Check iPhone battery** - it relays the stream
- **Restart GoPro Quik app**
- **Verify server is running:**
  ```bash
  curl -I https://stream.ogulcanaydogan.com/stat
  ```
  Should return `HTTP/2 200`

### Viewers Can't See Stream
- **Make sure you've started streaming** from GoPro first
- **Wait 10-15 seconds** for HLS segments to generate
- **Try hard refresh** in browser: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
- **Check if stream is active:**
  ```bash
  curl -I https://stream.ogulcanaydogan.com/hls/ogulcan.m3u8
  ```
  Should return `HTTP/2 200` (not 404)

### Stream is Laggy
- **Move closer to GoPro** - WiFi range is ~10 meters
- **Check iPhone WiFi connection** to GoPro
- **Reduce background apps** on iPhone

### "Server Not Found" Error
- **Server might be stopped** - run `./start-server.sh`
- **DNS not propagated yet** - the start script waits 3 minutes automatically
- **Check server status:**
  ```bash
  cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
  terraform output
  ```

---

## 📞 Quick Commands Reference

### Start Server (Fully Automated):
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream
./start-server.sh
```
Waits 5 minutes and configures everything automatically including SSL.

### Stop Server:
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream
./stop-server.sh
```

### Check Server Status:
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
terraform output
```

### Test Stream:
```bash
curl -I https://stream.ogulcanaydogan.com/hls/ogulcan.m3u8
```

### Test with VLC:
1. Open VLC Media Player
2. File → Open Network Stream
3. Paste: `https://stream.ogulcanaydogan.com/hls/ogulcan.m3u8`
4. Click Play

---

## 🎥 Tips for Better Streams

### Battery Life:
- **GoPro drains fast** when streaming (1-2 hours max)
- Use **external battery pack** or USB power adapter
- Keep **iPhone charged** too

### Positioning:
- **Test the angle** before going live
- **Check audio** - GoPro Hero 7 has decent mics
- **Stable mount** - avoid shaky footage

### Connection:
- **Stay within 10 meters** of GoPro
- **Use 5GHz WiFi** for better bandwidth
- **Avoid WiFi interference** (many other devices nearby)

### Sharing:
- **Share link in advance** so people can test
- **Start stream 5 minutes early** to test everything
- **Have a backup** - record locally on GoPro too

---

## 🔐 Security Notes

- **HTTPS enabled** - all streaming is encrypted
- **SSL certificate** auto-renews every 90 days (certbot timer enabled)
- **RTMP stream key** - use a unique, hard-to-guess stream key in `terraform.tfvars`
- **IP restrictions** - configure `rtmp_cidr_blocks` in `terraform.tfvars` to restrict who can publish
- **Content Security Policy** - web player has CSP headers to prevent XSS attacks
- **No viewer authentication** - anyone with the link can watch
  - Keep your stream URL private if you don't want public access
  - Or share it publicly - up to you!

---

## 📊 Architecture

```
GoPro Hero 7 Black
    ↓ WiFi
iPhone (GoPro Quik app)
    ↓ RTMP over Internet
AWS EC2 Server (Nginx-RTMP)
    ↓ Converts to HLS + HTTPS
    ↓
CloudFront (live.ogulcanaydogan.com)
    ↓ HTTPS
Viewers' Browsers
```

---

## 🛠️ Advanced: Manual Server Commands

**SSH to server** (if needed for debugging):
```bash
# Get current server IP first
cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
terraform output rtmp_server_ip

# Then SSH using IP (use the same key path you configured for start-server.sh)
SSH_KEY_PATH=~/.ssh/gopro-rtmp.pem  # or ~/Downloads/mac25.pem
ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -F /dev/null ubuntu@<SERVER_IP>
```

**Check Nginx status:**
```bash
sudo systemctl status nginx
```

**View logs:**
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

**Check HLS files:**
```bash
ls -lh /var/www/hls/
```

**Restart Nginx:**
```bash
sudo systemctl restart nginx
```

---

## 📝 Technical Details

- **Server:** Ubuntu 22.04 on AWS EC2 t3.small
- **RTMP Server:** Nginx with RTMP module (automatically configured)
- **SSL/TLS:** Let's Encrypt (obtained automatically on each start)
- **HLS Settings:** 2-second fragments, 10-second playlist
- **Latency:** ~10-15 seconds (typical for HLS)
- **Max viewers:** ~50-100 concurrent (can scale up if needed)
- **DNS:** Automatic updates via Terraform (Route53 with 60s TTL)
- **IP Address:** Changes on each deployment, DNS auto-updates
- **Cost Savings:** No Elastic IP charges (~$3.60/month saved)

---

## ✅ Pre-Stream Checklist

**Friday/Saturday:**
- [ ] Run `./start-server.sh` and wait 5 minutes
- [ ] Script will confirm when ready with all URLs
- [ ] Test by doing a 30-second stream
- [ ] Verify viewer link works (https://live.ogulcanaydogan.com)

**Sunday Morning:**
- [ ] Charge GoPro fully
- [ ] Charge iPhone fully
- [ ] Test GoPro Quik app connection
- [ ] Have external battery ready

**At the Pub:**
- [ ] Position GoPro with good angle
- [ ] Test 30-second stream to check audio/video
- [ ] Share link with viewers
- [ ] Go live!

**After Stream:**
- [ ] Stop streaming in GoPro Quik
- [ ] Run `./stop-server.sh` to save money
- [ ] Download any recordings from GoPro if needed

---

## 🎉 That's It!

You're all set for Sunday streaming. Questions? Everything is configured and ready to go!

**Need help?** Check the troubleshooting section above or test everything a day before your event.

Happy streaming! 📹🍻
