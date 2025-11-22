# GoPro Live Stream - Quick Start Guide

Your personal GoPro Hero 7 Black live streaming setup with HTTPS support.

## 🎯 Your Stream URLs

**These URLs never change:**

- **Web Player (share with viewers):** https://live.ogulcanaydogan.com
- **RTMP Ingest (for GoPro):** rtmp://stream.ogulcanaydogan.com/live/ogulcan
- **HLS Stream URL:** https://stream.ogulcanaydogan.com/hls/ogulcan.m3u8
- **Stats Page:** https://stream.ogulcanaydogan.com/stat

---

## 🚀 How to Stream (Quick Version)

### Before Your Event:

**1. Start the RTMP server** (Friday or Saturday before Sunday stream):
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
terraform apply -var="deploy_rtmp_server=true" -auto-approve
```
Wait ~2 minutes for the server to start.

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
cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
terraform apply -var="deploy_rtmp_server=false" -auto-approve
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
cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
terraform apply -var="deploy_rtmp_server=true" -auto-approve
```
This starts your RTMP server. Takes ~2 minutes.

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
cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
terraform apply -var="deploy_rtmp_server=false" -auto-approve
```
This stops the server and saves money.

---

## 💰 Cost Breakdown

**When Server is Running:**
- EC2 t3.small: ~$0.50/day (~$15/month if left on)
- Data transfer: ~$0.09/GB

**When Server is Stopped:**
- $0/month - Everything is deleted except DNS records

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
- **Server might be stopped** - run the start command
- **DNS not propagated yet** - wait 2-3 minutes after starting server
- **Check server status:**
  ```bash
  cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
  terraform output
  ```

---

## 📞 Quick Commands Reference

### Start Server:
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
terraform apply -var="deploy_rtmp_server=true" -auto-approve
```

### Stop Server:
```bash
cd ~/Desktop/ogulcanaydogan/gopro-live-stream/infra
terraform apply -var="deploy_rtmp_server=false" -auto-approve
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
- **SSL certificate** auto-renews every 90 days
- **No authentication** - anyone with the link can watch
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
ssh -i ~/Downloads/mac25.pem ubuntu@3.230.37.216
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
- **RTMP Server:** Nginx with RTMP module
- **SSL/TLS:** Let's Encrypt (auto-renewing)
- **HLS Settings:** 2-second fragments, 10-second playlist
- **Latency:** ~10-15 seconds (typical for HLS)
- **Max viewers:** ~50-100 concurrent (can scale up if needed)

---

## ✅ Pre-Stream Checklist

**Friday/Saturday:**
- [ ] Start the RTMP server
- [ ] Test by doing a 30-second stream
- [ ] Verify viewer link works

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
- [ ] Stop the server to save money
- [ ] Download any recordings from GoPro if needed

---

## 🎉 That's It!

You're all set for Sunday streaming. Questions? Everything is configured and ready to go!

**Need help?** Check the troubleshooting section above or test everything a day before your event.

Happy streaming! 📹🍻
