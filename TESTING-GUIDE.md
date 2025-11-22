# ✅ RTMP Server is Ready for Testing!

## 🎯 Server Status: **ONLINE**

Your RTMP server at **3.230.37.216** is fully configured and ready.

### Verified Working:
- ✅ HTTP/Nginx running
- ✅ RTMP port 1935 open
- ✅ HLS directory configured
- ✅ CORS headers enabled

---

## 📱 Test with GoPro (Easiest)

### On iPhone with GoPro Quik App:

1. **Connect GoPro** to your iPhone via WiFi
2. **Open GoPro Quik** app
3. Tap the **Live** button
4. Select **RTMP**
5. Choose **Custom**
6. Enter this URL:
   ```
   rtmp://3.230.37.216/live/ogulcan
   ```
7. Tap **Go Live**
8. Wait 10-15 seconds

### On Your Computer:

1. Open **https://live.ogulcanaydogan.com**
2. Paste this HLS URL:
   ```
   http://3.230.37.216/hls/ogulcan.m3u8
   ```
3. Click **Start Stream**
4. You should see your GoPro feed!

---

## 💻 Test with OBS Studio (Alternative)

If you want to test without GoPro:

1. **Download OBS Studio**: https://obsproject.com
2. Open OBS → **Settings** → **Stream**
3. Service: **Custom**
4. Server: `rtmp://3.230.37.216/live`
5. Stream Key: `ogulcan`
6. Click **OK** then **Start Streaming**
7. Open https://live.ogulcanaydogan.com
8. Paste: `http://3.230.37.216/hls/ogulcan.m3u8`

---

## 🧪 Quick FFmpeg Test

If you just want to verify it works:

```bash
# Stream a test pattern for 10 seconds
ffmpeg -re -f lavfi -i testsrc=size=1280x720:rate=30 \
  -f lavfi -i sine=frequency=1000 \
  -c:v libx264 -preset veryfast -b:v 2500k \
  -c:a aac -b:a 128k \
  -f flv rtmp://3.230.37.216/live/ogulcan \
  -t 10
```

Then immediately open your browser to https://live.ogulcanaydogan.com and paste:
```
http://3.230.37.216/hls/ogulcan.m3u8
```

---

## 🔍 Troubleshooting

### Stream not appearing?
```bash
# Check if HLS files are being created
ssh -i ~/Downloads/mac25.pem ubuntu@3.230.37.216 "ls -lh /var/www/hls/"
```

### Check Nginx logs:
```bash
ssh -i ~/Downloads/mac25.pem ubuntu@3.230.37.216 "sudo tail -f /var/log/nginx/access.log"
```

### View RTMP stats:
Open: http://3.230.37.216/stat

---

## 💰 Remember: When Done Streaming

Stop the server to save costs:

```bash
cd infra
terraform apply -var="deploy_rtmp_server=false" -auto-approve
```

This destroys the EC2 instance. Deploy again when needed by setting it back to `true`.

---

## 🎉 You're All Set!

Everything is working and ready for your GoPro stream!
