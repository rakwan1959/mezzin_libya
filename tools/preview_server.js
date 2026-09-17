// Minimal static file server for previewing the Flutter web build (build/web).
// Usage: node tools/preview_server.js [port] [root]
// Defaults: port 8080, root build/web
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.argv[2] || '8080', 10);
const ROOT = path.resolve(process.argv[3] || 'build/web');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
  '.pdf': 'application/pdf',
  '.mp3': 'audio/mpeg',
  '.db': 'application/octet-stream',
};

http.createServer((req, res) => {
  const urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  let filePath = path.join(ROOT, path.normalize(urlPath));
  if (!filePath.startsWith(ROOT)) filePath = path.join(ROOT, 'index.html');
  fs.stat(filePath, (err, stat) => {
    if (!err && stat.isDirectory()) filePath = path.join(filePath, 'index.html');
    fs.readFile(filePath, (err2, data) => {
      if (err2) {
        // SPA fallback: serve index.html for unknown routes
        fs.readFile(path.join(ROOT, 'index.html'), (e3, idx) => {
          if (e3) {
            res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
            res.end('Not found');
            return;
          }
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          res.end(idx);
        });
        return;
      }
      res.writeHead(200, {
        'Content-Type': MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
        'Cache-Control': 'no-cache',
      });
      res.end(data);
    });
  });
}).listen(PORT, '127.0.0.1', () => {
  console.log(`Serving ${ROOT} at http://127.0.0.1:${PORT}`);
});