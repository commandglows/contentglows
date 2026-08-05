/**
 * Static file server for Flutter web build.
 * Serves build/web/ with SPA fallback (all routes → index.html).
 *
 * Usage: node server.js [port]
 * Default port: 3050
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.PORT || process.argv[2] || '3050');
const BUILD_DIR = path.join(__dirname, 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
};

const NO_CACHE_FILES = new Set([
  'index.html',
  'main.dart.js',
  'flutter.js',
  'flutter_service_worker.js',
  'version.json',
  'manifest.json',
]);

const server = http.createServer((req, res) => {
  // CORS for API proxy
  res.setHeader('Access-Control-Allow-Origin', '*');

  const requestPath = new URL(req.url, 'http://localhost').pathname;
  let filePath = path.join(
    BUILD_DIR,
    requestPath === '/' ? 'index.html' : requestPath,
  );

  // Security: prevent directory traversal
  if (!filePath.startsWith(BUILD_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  // Try the exact file first
  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    const ext = path.extname(filePath);
    const mime = MIME_TYPES[ext] || 'application/octet-stream';

    // Flutter boot files retain stable names across builds, so they must not
    // be immutable or browsers can keep running an obsolete application.
    const cacheControl = NO_CACHE_FILES.has(path.basename(filePath))
      ? 'no-cache, no-store, must-revalidate'
      : 'public, max-age=31536000, immutable';

    res.writeHead(200, {
      'Content-Type': mime,
      'Cache-Control': cacheControl,
    });
    fs.createReadStream(filePath).pipe(res);
    return;
  }

  // Directory index support for auth routes like /sign-in and /sso-callback
  if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    const nestedIndexPath = path.join(filePath, 'index.html');
    if (fs.existsSync(nestedIndexPath) && fs.statSync(nestedIndexPath).isFile()) {
      res.writeHead(200, {
        'Content-Type': 'text/html',
        'Cache-Control': 'no-cache',
      });
      fs.createReadStream(nestedIndexPath).pipe(res);
      return;
    }
  }

  const authRoute = requestPath.match(/^\/(sign-in|sign-up)(?:\/|$)/);
  if (authRoute) {
    const authIndexPath = path.join(BUILD_DIR, authRoute[1], 'index.html');
    if (fs.existsSync(authIndexPath) && fs.statSync(authIndexPath).isFile()) {
      res.writeHead(200, {
        'Content-Type': 'text/html',
        'Cache-Control': 'no-cache',
      });
      fs.createReadStream(authIndexPath).pipe(res);
      return;
    }
  }

  // SPA fallback: serve index.html for all routes (GoRouter handles client-side)
  const indexPath = path.join(BUILD_DIR, 'index.html');
  if (fs.existsSync(indexPath)) {
    res.writeHead(200, {
      'Content-Type': 'text/html',
      'Cache-Control': 'no-cache',
    });
    fs.createReadStream(indexPath).pipe(res);
  } else {
    res.writeHead(404);
    res.end('Not found. Run: flutter build web');
  }
});

server.listen(PORT, () => {
  console.log(`ContentGlows app serving on http://localhost:${PORT}`);
  console.log(`   Serving: ${BUILD_DIR}`);
});
