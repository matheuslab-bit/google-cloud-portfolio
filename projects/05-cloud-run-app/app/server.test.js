'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { route, createServer } = require('./server');

test('health check answers ok', () => {
  assert.deepEqual(route('GET', '/healthz'), { status: 200, body: { status: 'ok' } });
});

test('root reports whether the secret was injected, never its value', () => {
  process.env.APP_GREETING = 'super secret value';
  const { status, body } = route('GET', '/');
  assert.equal(status, 200);
  assert.equal(body.greetingConfigured, true);
  assert.ok(!JSON.stringify(body).includes('super secret value'));
  delete process.env.APP_GREETING;
});

test('unknown paths and other methods are rejected', () => {
  assert.equal(route('GET', '/admin').status, 404);
  assert.equal(route('POST', '/').status, 405);
});

test('the HTTP server answers on a random port', async () => {
  const server = createServer().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const { port } = server.address();
  const response = await fetch(`http://127.0.0.1:${port}/healthz`);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('content-type'), 'application/json');
  server.close();
});
