{{flutter_js}}
{{flutter_build_config}}

window.addEventListener('flutter-first-frame', () => {
  document.documentElement.dataset.loadMs = performance.now().toFixed(1);
  document.documentElement.dataset.flutterReady = 'true';
  document.getElementById('startup')?.remove();
}, { once: true });

_flutter.loader.load().catch(() => {
  document.getElementById('startup-message').textContent =
    'Не удалось загрузить приложение. Проверьте соединение.';
  document.getElementById('startup-retry').hidden = false;
});
