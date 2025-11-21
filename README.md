# GoPro Live Stream

A minimal web player and Terraform stack to host a private GoPro livestream viewed through HLS (tested with the Hero 7 Black but not limited to it). The flow stays the same:

GoPro → GoPro Quik (iPhone) → RTMP ingest (Nginx-RTMP or similar) → HLS → S3 + CloudFront player.

## Web player (HLS)

The `/web` folder contains a single-page viewer (`index.html`) that:
- Plays HLS streams with native Safari playback on iOS and Hls.js elsewhere.
- Lets you paste your own playlist URL (cached in localStorage).
- Shows live/offline/loading states and a quick checklist for the GoPro + iPhone workflow.
- Exposes a diagnostics panel (resolution/bitrate/buffer/frames) plus a live log for quick triage.
- Supports Picture-in-Picture and one-click share links for the player or preview mode.
- Includes a local-only viewer chat box (optional persistence) you can wire to a WebSocket or API for shared chat.

### Local preview

```bash
cd web
python -m http.server 8000
# open http://localhost:8000 and paste your HLS URL
```

### Generate a static preview image

The web player supports `?preview=true` to avoid loading a real HLS feed. A helper script saves a PNG of the page (useful for
documentation or PRs).

```bash
# one-time
npm install

# create web/preview.png without hitting a live stream
npm run preview
```

If the environment blocks `npm install`, you can still commit a visual using the offline-only helper that draws a styled mock of
the player without external dependencies:

```bash
python scripts/build-static-preview.py  # writes web/preview.png
```

#### Always-on previews (CI)

Every push and pull request runs the **Preview** workflow, which installs Playwright, renders `index.html?preview=true`, and
uploads `web/preview.png` as a build artifact. This gives you an up-to-date screenshot for reviews without requiring a live
stream.

## Deploy with Terraform (S3 + CloudFront)

The `/infra` folder provisions an S3 bucket for the player assets and a CloudFront distribution locked to the bucket via Origin Access Control (OAC).

### Prerequisites
- Terraform >= 1.5
- AWS credentials configured
- A unique S3 bucket name (`bucket_name` variable)
- Optional: a domain + ACM certificate in `us-east-1` if you want a vanity hostname

### Variables
- `bucket_name` (required): target bucket for the static site
- `region` (default `us-east-1`): AWS region
- `domain_name` (optional): e.g., `live.example.com`
- `acm_certificate_arn` (required if `domain_name` is set): ACM cert in `us-east-1`
- `environment` / `tags`: metadata applied to resources

### Deploy
```bash
cd infra
terraform init
terraform apply \
  -var "bucket_name=your-unique-bucket" \
  -var "domain_name=live.example.com" \  # omit if you will use the CloudFront domain
  -var "acm_certificate_arn=arn:aws:acm:us-east-1:..."    # required when domain_name is set
```

Outputs:
- `cloudfront_domain_name`: URL to load the player (use this if no custom domain)
- `website_bucket`: bucket that holds `index.html` and `styles.css`

### DNS (optional)
If you provided `domain_name`, point a Route53/other DNS CNAME/ALIAS at the `cloudfront_domain_name` output.

### End-to-end steps (from deploy to watching)
1. **Plan variables**: Pick a unique `bucket_name`. If you want a custom domain (e.g., `live.example.com`), issue an ACM
   certificate in `us-east-1` and note its ARN for `acm_certificate_arn`.
2. **Apply Terraform**: From `/infra`, run `terraform init` then `terraform apply` with the variables above. Wait for the
   outputs.
3. **Upload the player**: Copy `web/index.html` and `web/styles.css` into the S3 bucket output as `website_bucket`. The
   Terraform stack already makes the bucket private and serves it through CloudFront via Origin Access Control, so no
   bucket ACL changes are needed.
4. **(Optional) Point DNS**: If using a vanity hostname, create a CNAME/ALIAS to the `cloudfront_domain_name` output.
5. **Prepare the ingest**: Ensure your RTMP server (e.g., Nginx-RTMP) emits HLS at a URL like
   `https://YOUR_DOMAIN/live/ogulcan/index.m3u8` that is reachable by CloudFront. Open ports 80/443 (and 1935 for RTMP
   publishing) on the ingest host.
6. **Stream from GoPro**: In the GoPro Quik app on iPhone, choose Live → RTMP → Custom and enter
   `rtmp://<SERVER_IP>/live/ogulcan` (or your path). Start streaming and wait a few HLS fragments to accumulate.
7. **Watch**: Visit the CloudFront URL (or your domain), paste the HLS playlist URL into the player, and click **Start
   Stream**. The player remembers the URL locally for future visits.

## GoPro + iPhone workflow (also displayed in the page footer; tested with Hero 7 Black)
1. **Prep ingest:** On your RTMP ingest (e.g., Nginx-RTMP) ensure HLS is emitted at `https://YOUR_DOMAIN/live/<channel>/index.m3u8`.
2. **Point the GoPro:** In the GoPro Quik app (iPhone): Live → RTMP → Custom, enter `rtmp://<SERVER_IP>/live/ogulcan` (or your path).
3. **Start the feed:** Go live on the GoPro; wait a few HLS fragments.
4. **Load the player:** Open the player URL, paste the HLS URL, and click **Start Stream**.
5. **Add chat:** Start the included chat relay (below) or your own WebSocket backend, paste its URL in the player, choose a room, and click **Connect** so every viewer can post with their name.

## Hooking up the chat box (shared across viewers)
- The chat panel now accepts a WebSocket URL plus a room name. With no URL it stays local-only for previews; with a URL it becomes multi-viewer.
- A lightweight relay is included for quick tests: `npm install` then `npm run chat-server` (defaults to `ws://localhost:8787`). You can point the player to `ws://YOUR_HOST:8787?room=gopro`.
- Bring-your-own backend works too (API Gateway WebSockets, Supabase Realtime, Firebase, Ably, Socket.IO, etc.). The client sends `{ type: "chat-message", name, text, ts, room }` and expects the same payload broadcast to all participants.
- Chat history persists only if "Persist locally" is enabled; otherwise messages clear when you reload.

## Suggested Features & Improvements

### Reliability & Scalability
- **Health checks and auto-restart:** Use `systemd` unit files with `Restart=on-failure` for nginx-rtmp and any sidecar processes to keep the ingest stack resilient.
- **Metrics and dashboards:** Expose Nginx RTMP metrics via the [nginx-vts-exporter](https://github.com/hnlq715/nginx-vts-exporter) or similar Prometheus exporter and visualize stream bitrate, viewers, and error rates in Grafana.
- **Autoscaling for spikes:** Place the RTMP/HLS stack behind an autoscaling group (ASG on AWS or scale set on DO) with a load balancer that forwards RTMP (1935/TCP) and HLS (80/443) to handle peak events.

### Security & Access Control
- **TLS everywhere:** Terminate TLS on the load balancer and ensure HLS delivery over HTTPS to avoid mixed-content issues in browsers.
- **Origin shielding & signed URLs:** Enable CloudFront Origin Shield and signed URLs/cookies for `/live/ogulcan/` to prevent link sharing and control viewer access windows.
- **Firewall hardening:** Lock inbound rules to only needed ports (80/443/1935) and restrict SSH by IP; enable fail2ban for brute-force protection.

### Streaming Quality
- **Adaptive bitrate (ABR):** Configure multiple variant HLS playlists (e.g., 1080p/6Mbps, 720p/3Mbps, 480p/1.5Mbps) to improve playback on varying networks.
- **DVR rewind:** Increase `hls_playlist_length` and keep short fragments (e.g., 2s) so viewers can scrub back 30–60 minutes while keeping latency reasonable.
- **Low-latency HLS:** Enable LL-HLS on the origin (if supported) and CloudFront to reduce end-to-end delay for interactive streams.

### Operational Tooling
- **CI/CD for config:** Manage Nginx configs, TLS certificates, and player assets in Git with automated validation (e.g., `nginx -t` and HTML lint) before deployment.
- **Automated backups:** Snapshot the Droplet/EC2 volume and back up `/etc/nginx` and `/var/www/hls` configs regularly.
- **Infra as code:** Capture the full stack in Terraform (DO or AWS providers) to recreate the environment quickly and track changes.

### Viewer Experience
- **Custom player controls:** Add a branded player UI with start/stop indicators, chat integration (e.g., AWS API Gateway + WebSockets), and viewer count overlay pulled from metrics.
- **Fallback and error messaging:** Show clear offline/starting/error states and retry logic if the playlist is temporarily unavailable.
- **Geo/Device analytics:** Use lightweight analytics (e.g., CloudFront logs to Athena/QuickSight) to understand audience regions and device performance.

### Cost Optimization
- **Tiered cache policies:** Set longer TTLs on static player assets and moderate TTLs on segments; enable compression where applicable.
- **Storage lifecycle policies:** Apply S3 lifecycle rules to expire old HLS fragments and logs, keeping storage costs predictable.
