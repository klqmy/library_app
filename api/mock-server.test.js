'use strict';
const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const net = require('node:net');
const path = require('node:path');
let base;
const children = [];
const pause = (ms) => new Promise((r) => setTimeout(r, ms));
async function request(method, route, token, body, status = 200, serverBase = base) {
  const response = await fetch(serverBase + route, { method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  const data = response.status === 204 ? null : await response.json();
  assert.equal(response.status, status, `${method} ${route}: ${JSON.stringify(data)}`);
  return data;
}
async function login(username) {
  return request('POST', '/auth/login', null, { username, password: username + '123' });
}
async function startServer(ttl = 900) {
  const probe = net.createServer();
  await new Promise((r) => probe.listen(0, '127.0.0.1', r));
  const port = probe.address().port;
  await new Promise((r) => probe.close(r));
  const serverBase = `http://localhost:${port}/api`;
  const child = spawn(process.execPath, [path.join(__dirname, 'mock-server.js'), '--port', String(port), '--ttl', String(ttl)], { stdio: 'ignore' });
  children.push(child);
  for (let i = 0; i < 50; i++) {
    try { await request('GET', '/__health', null, undefined, 200, serverBase); return serverBase; } catch { await pause(50); }
  }
  throw new Error('Учебный API не запустился');
}
before(async () => { base = await startServer(); });
beforeEach(async () => { const admin = await login('admin'); await request('POST', '/__reset', admin.accessToken); });
after(async () => {
  for (const child of children) {
    if (child.exitCode !== null) continue;
    const stopped = new Promise((resolve) => child.once('exit', resolve));
    child.kill();
    await stopped;
  }
});

test('внутренние ресурсы требуют токен', async () => {
  for (const route of ['/books', '/readers', '/loans', '/users', '/stats']) await request('GET', route, null, undefined, 401);
});
test('регистрация проверяет пароль и всегда создаёт читателя', async () => {
  const data = { username: 'new_reader', fullName: 'Новый читатель', email: 'new@example.com', password: 'Password123', role: 'admin' };
  const error = await request('POST', '/auth/register', null, data, 422);
  assert.ok(error.errors.password);
  data.password += '!';
  const user = await request('POST', '/auth/register', null, data, 201);
  assert.equal(user.role, 'reader'); assert.ok(user.readerId);
  const auth = await request('POST', '/auth/login', null, { username: data.username, password: data.password });
  assert.equal(auth.user.role, 'reader'); assert.equal('passwordHash' in auth.user, false);
});
test('читатель видит только свои записи и не получает чужие по id', async () => {
  const admin = await login('admin'), reader = await login('reader');
  const own = await request('GET', '/loans', reader.accessToken);
  assert.ok(own.items.every((x) => x.reader.id === reader.user.readerId));
  const all = await request('GET', '/loans', admin.accessToken);
  const foreign = all.items.find((x) => x.reader.id !== reader.user.readerId);
  await request('GET', `/loans/${foreign.id}`, reader.accessToken, undefined, 403);
  await request('GET', '/readers/2', reader.accessToken, undefined, 403);
  const readers = await request('GET', '/readers', reader.accessToken);
  assert.deepEqual(readers.items.map((r) => r.id), [reader.user.readerId]);
});
test('читатель продлевает только собственную выдачу', async () => {
  const reader = await login('reader');
  const data = await request('GET', '/loans', reader.accessToken);
  const loan = data.items.find((x) => x.status !== 'returned');
  const changed = await request('POST', `/loans/${loan.id}/extend`, reader.accessToken);
  assert.ok(Date.parse(changed.dueAt) > Date.parse(loan.dueAt));
  await request('POST', '/loans/2/extend', reader.accessToken, undefined, 403);
  const admin = await login('admin');
  await request('POST', `/loans/${loan.id}/extend`, admin.accessToken, undefined, 403);
});
test('подсказка роли клиента не даёт административных прав', async () => {
  const reader = await login('reader');
  const forgedProfile = { ...reader.user, role: 'admin' };
  assert.equal(forgedProfile.role, 'admin');
  await request('GET', '/users', reader.accessToken, undefined, 403);
  await request('GET', '/stats', reader.accessToken, undefined, 403);
  await request('POST', '/authors', reader.accessToken, { fullName: 'Попытка записи', country: 'Россия', role: forgedProfile.role }, 403);
});
test('библиотекарь меняет каталог, а физическое удаление и восстановление выполняет администратор', async () => {
  const staff = await login('librarian'), admin = await login('admin');
  const author = await request('POST', '/authors', staff.accessToken, { fullName: 'Новый автор', country: 'Россия' }, 201);
  await request('DELETE', `/authors/${author.id}?hard=true`, staff.accessToken, undefined, 403);
  await request('DELETE', `/authors/${author.id}`, staff.accessToken, undefined, 204);
  await request('POST', `/authors/${author.id}/restore`, staff.accessToken, undefined, 403);
  await request('POST', `/authors/${author.id}/restore`, admin.accessToken);
  await request('DELETE', `/authors/${author.id}?hard=true`, admin.accessToken, undefined, 204);
});
test('только администратор управляет пользователями и статистикой', async () => {
  const staff = await login('librarian'), admin = await login('admin');
  await request('GET', '/users', staff.accessToken, undefined, 403);
  await request('PUT', '/users/3', staff.accessToken, { role: 'admin' }, 403);
  const changed = await request('PUT', '/users/3', admin.accessToken, { role: 'librarian' });
  assert.equal(changed.role, 'librarian');
  const stats = await request('GET', '/stats', admin.accessToken);
  assert.equal(stats.books, 20); assert.equal(stats.users, 3);
  await request('PUT', '/users/1', admin.accessToken, { role: 'reader' }, 409);
});
test('истёкший токен обновляется, использованный refresh отклоняется', async () => {
  const shortSessionBase = await startServer(2);
  const shortRequest = (method, route, token, body, status = 200) =>
    request(method, route, token, body, status, shortSessionBase);
  const auth = await shortRequest('POST', '/auth/login', null, { username: 'reader', password: 'reader123' });
  await pause(2250);
  await shortRequest('GET', '/books', auth.accessToken, undefined, 401);
  const next = await shortRequest('POST', '/auth/refresh', null, { refreshToken: auth.refreshToken });
  assert.notEqual(next.accessToken, auth.accessToken);
  await shortRequest('GET', '/books', next.accessToken);
  await shortRequest('POST', '/auth/refresh', null, { refreshToken: auth.refreshToken }, 401);
  await shortRequest('POST', '/auth/logout', null, { refreshToken: next.refreshToken }, 204);
  await shortRequest('POST', '/auth/refresh', null, { refreshToken: next.refreshToken }, 401);
});
