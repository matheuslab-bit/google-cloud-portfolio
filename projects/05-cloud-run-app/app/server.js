'use strict';

// Small status API used to exercise Cloud Run, Artifact Registry and Secret Manager.
// No dependencies: only the Node.js standard library.

const http = require('node:http');

const VERSION = process.env.APP_VERSION || 'dev';
const START = Date.now();

function route(method, url) {
  if (method !== 'GET') {
    return { status: 405, body: { error: 'method not allowed' } };
  }
  if (url === '/healthz') {
    return { status: 200, body: { status: 'ok' } };
  }
  if (url === '/') {
    return {
      status: 200,
      body: {
        service: process.env.K_SERVICE || 'local',
        revision: process.env.K_REVISION || 'local',
        version: VERSION,
        uptimeSeconds: Math.round((Date.now() - START) / 1000),
        // Proves the secret was injected without ever returning its value.
        greetingConfigured: Boolean(process.env.APP_GREETING),
      },
    };
  }
  return { status: 404, body: { error: 'not found' } };
}

function createServer() {
  return http.createServer((req, res) => {
    const { status, body } = route(req.method, req.url.split('?')[0]);
    res.writeHead(status, { 'content-type': 'application/json', 'cache-control': 'no-store' });
    res.end(JSON.stringify(body));
    // One JSON line per request: Cloud Logging parses it as a structured entry.
    console.log(JSON.stringify({ severity: status >= 500 ? 'ERROR' : 'INFO', method: req.method, path: req.url, status }));
  });
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 8080;
  const server = createServer().listen(port, () => console.log(JSON.stringify({ severity: 'INFO', message: `listening on ${port}` })));
  // Cloud Run sends SIGTERM before stopping an instance; finish in-flight requests first.
  process.on('SIGTERM', () => server.close(() => process.exit(0)));
}

module.exports = { route, createServer };
