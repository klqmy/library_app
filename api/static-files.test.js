'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { spawn } = require('node:child_process');
let directory, child, base;

before(async () => {
  directory = await fs.mkdtemp(path.join(os.tmpdir(), 'library-web-'));
  await fs.writeFile(path.join(directory, 'index.html'), '<html>Flutter</html>');
  await fs.writeFile(path.join(directory, 'main.dart.mjs'), 'export const ready = true;');
  await fs.writeFile(path.join(directory, 'main.dart.wasm'), Buffer.from([0, 97, 115, 109]));
  const probe = net.createServer();
  await new Promise((resolve) => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port;
  await new Promise((resolve) => probe.close(resolve));
  base = `http://127.0.0.1:${port}`;
  child = spawn(process.execPath, [path.join(__dirname, 'mock-server.js'), '--web-root', directory], {
    stdio: 'ignore', env: { ...process.env, PORT: String(port) },
  });
  for (let i = 0; i < 60; i++) {
    try {
      const response = await fetch(base + '/api/__health');
      if (response.ok) return;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error('Сервер клиента и API не запустился');
});

after(async () => {
  if (child && child.exitCode === null) {
    const stopped = new Promise((resolve) => child.once('exit', resolve));
    child.kill();
    await stopped;
  }
  if (directory) {
    const target = path.resolve(directory);
    assert.equal(path.dirname(target), path.resolve(os.tmpdir()));
    assert.ok(path.basename(target).startsWith('library-web-'));
    assert.equal(await fs.realpath(target), target);
    await fs.rm(target, { recursive: true, force: true });
  }
});

test('корень, внутренний адрес и обновление страницы возвращают клиент', async () => {
  for (const route of ['/', '/books', '/books/1', '/admin/users']) {
    const response = await fetch(base + route);
    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type'), /text\/html/);
    assert.equal(await response.text(), '<html>Flutter</html>');
  }
});

test('модули и Wasm имеют правильный MIME, HEAD не возвращает тело', async () => {
  for (const [file, type] of [['main.dart.mjs', 'application/javascript'], ['main.dart.wasm', 'application/wasm']]) {
    const response = await fetch(base + '/' + file, { method: 'HEAD' });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-type'), type);
    assert.equal(response.headers.get('cross-origin-opener-policy'), 'same-origin');
    assert.equal(response.headers.get('cross-origin-embedder-policy'), 'credentialless');
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(await response.text(), '');
  }
});

test('отсутствующий ресурс и POST не маскируются HTML приложения', async () => {
  assert.equal((await fetch(base + '/missing.js')).status, 404);
  assert.equal((await fetch(base + '/books', { method: 'POST' })).status, 405);
  assert.equal((await fetch(base + '/%2e%2e%2foutside.txt')).status, 403);
  assert.equal((await fetch(base + '/%00')).status, 400);
});

test('клиент и авторизованный API работают на одном адресе', async () => {
  const response = await fetch(base + '/api/auth/login', { method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'reader', password: 'reader123' }) });
  assert.equal(response.status, 200);
  const auth = await response.json();
  const books = await fetch(base + '/api/books?page=1&size=10', {
    headers: { Authorization: 'Bearer ' + auth.accessToken },
  });
  assert.equal(books.status, 200);
  assert.equal((await books.json()).items.length, 10);
  const missing = await fetch(base + '/api/missing', {
    headers: { Authorization: 'Bearer ' + auth.accessToken },
  });
  assert.equal(missing.status, 404);
  assert.match(missing.headers.get('content-type'), /application\/json/);
});
