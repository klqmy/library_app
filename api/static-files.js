'use strict';
const fs = require('node:fs');
const path = require('node:path');

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
};

function createStaticHandler(directory) {
  const root = fs.realpathSync(directory);
  if (!fs.statSync(path.join(root, 'index.html')).isFile()) {
    throw new Error('В каталоге клиента нет index.html');
  }
  const inside = (file) => {
    const relative = path.relative(root, file);
    return relative !== '..' && !relative.startsWith('..' + path.sep) && !path.isAbsolute(relative);
  };

  return async (req, res, url) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'credentialless');
    res.setHeader('Cache-Control', 'no-store');
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405, { Allow: 'GET, HEAD' });
      return res.end();
    }

    let requested;
    try {
      requested = decodeURIComponent(url.pathname);
      if (requested.includes('\0') || requested.includes('\\')) throw new Error();
    } catch {
      res.writeHead(400);
      return res.end();
    }

    let file = path.resolve(root, '.' + requested);
    if (!inside(file)) {
      res.writeHead(403);
      return res.end();
    }
    try {
      let stat = await fs.promises.stat(file).catch((error) => {
        if (error.code === 'ENOENT' || error.code === 'ENOTDIR') return null;
        throw error;
      });
      if (!stat?.isFile() && !path.extname(requested)) {
        file = path.join(root, 'index.html');
        stat = await fs.promises.stat(file);
      }
      if (!stat?.isFile()) {
        res.writeHead(404);
        return res.end();
      }
      if (!inside(await fs.promises.realpath(file))) {
        res.writeHead(403);
        return res.end();
      }
      res.writeHead(200, {
        'Content-Type': types[path.extname(file)] || 'application/octet-stream',
        'Content-Length': stat.size,
      });
      if (req.method === 'HEAD') return res.end();
      const stream = fs.createReadStream(file);
      stream.on('error', () => res.destroy());
      stream.pipe(res);
    } catch (error) {
      console.error('Не удалось прочитать файл клиента:', error.code);
      res.writeHead(500);
      res.end();
    }
  };
}

module.exports = { createStaticHandler };
