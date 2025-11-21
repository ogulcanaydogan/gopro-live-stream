import { createServer } from 'http';
import { readFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { chromium } from 'playwright';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const webDir = path.join(rootDir, 'web');
const OUTPUT_PATH = path.join(webDir, 'preview.png');
const PORT = 4173;

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.m3u8': 'application/vnd.apple.mpegurl',
  '.ts': 'video/mp2t',
};

function getMime(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  return mimeTypes[ext] || 'application/octet-stream';
}

function startServer() {
  return new Promise((resolve) => {
    const server = createServer(async (req, res) => {
      try {
        const requestPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
        const normalized = requestPath === '/' ? '/index.html' : requestPath;
        const filePath = path.join(webDir, normalized);

        if (!filePath.startsWith(webDir)) {
          res.writeHead(403);
          res.end('Forbidden');
          return;
        }

        const contents = await readFile(filePath);
        res.writeHead(200, { 'Content-Type': getMime(filePath) });
        res.end(contents);
      } catch (error) {
        res.writeHead(404);
        res.end('Not found');
      }
    });

    server.listen(PORT, () => resolve(server));
  });
}

async function generatePreview() {
  const server = await startServer();
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1365, height: 768 } });
  try {
    await page.goto(`http://localhost:${PORT}/index.html?preview=true`, { waitUntil: 'networkidle' });
    await page.waitForSelector('header h1');
    await page.screenshot({ path: OUTPUT_PATH, fullPage: true });
    console.log(`Preview saved to ${OUTPUT_PATH}`);
  } finally {
    await browser.close();
    server.close();
  }
}

generatePreview().catch((error) => {
  console.error('Failed to generate preview:', error);
  process.exitCode = 1;
});
