from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlsplit, unquote
import argparse

parser = argparse.ArgumentParser(description='Локальная проверка Flutter Web')
parser.add_argument('directory', help='Каталог релизной сборки')
parser.add_argument('--port', type=int, default=8000)
parser.add_argument('--base-path', default='/')
args = parser.parse_args()
root = Path(args.directory).resolve()
prefix = '/' + args.base_path.strip('/') + '/' if args.base_path.strip('/') else '/'
if not (root / 'index.html').is_file():
    parser.error('В каталоге нет index.html')


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map,
                      '.js': 'application/javascript',
                      '.mjs': 'application/javascript',
                      '.wasm': 'application/wasm'}

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(root), **kw)

    def translate_path(self, path):
        requested = unquote(urlsplit(path).path)
        requested = requested[len(prefix):] if requested.startswith(prefix) else requested.lstrip('/')
        target = (root / requested).resolve()
        if not target.is_relative_to(root):
            return str(root / 'not-found')
        if not target.exists() and not Path(requested).suffix:
            return str(root / 'index.html')
        return str(target)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'credentialless')
        super().end_headers()


print(f'http://localhost:{args.port}{prefix}', flush=True)
ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
