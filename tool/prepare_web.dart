import 'dart:io';

void main(List<String> arguments) {
  if (arguments.isEmpty) throw ArgumentError('Укажите каталог сборки web');
  final root = Directory(arguments.first).absolute;
  final index = File('${root.path}/index.html');
  final bootstrap = File('${root.path}/flutter_bootstrap.js');
  if (!index.existsSync() || !bootstrap.existsSync()) {
    throw ArgumentError('Каталог не содержит готовую сборку Flutter Web');
  }
  final before = sizeOf(root);
  if (arguments.contains('--optimize')) {
    if (File('${root.path}/main.dart.wasm').existsSync()) {
      throw ArgumentError('Оптимизация предназначена только для JS-сборки');
    }
    final canvaskit = Directory('${root.path}/canvaskit');
    if (canvaskit.existsSync()) {
      for (final file
          in canvaskit
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()) {
        final name = file.uri.pathSegments.last;
        if (name.startsWith('skwasm') || name.endsWith('.symbols')) {
          final resolved = file.resolveSymbolicLinksSync();
          if (!resolved.startsWith(
            '${root.resolveSymbolicLinksSync()}${Platform.pathSeparator}',
          )) {
            throw StateError('Файл вне каталога сборки');
          }
          stdout.writeln(
            'Исключён неиспользуемый ресурс: ${file.path.substring(root.path.length + 1)}',
          );
          file.deleteSync();
        }
      }
    }
  }
  stdout.writeln('Размер: $before → ${sizeOf(root)} байт.');
}

int sizeOf(Directory root) => root
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .fold(0, (sum, file) => sum + file.lengthSync());
