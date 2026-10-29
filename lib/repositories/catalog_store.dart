import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/catalog_entity.dart';
import '../models/entity_kind.dart';
import '../data/seed_catalog.dart';

/// A single JSON snapshot keeps all linked records consistent after a reload.
class CatalogStore extends ChangeNotifier {
  static const storageKey = 'library_catalog_v3';
  static const schemaVersion = 3;
  final SharedPreferences preferences;
  Map<EntityKind, List<CatalogEntity>> _data = {};
  Map<EntityKind, int> _nextIds = {};
  Future<void> _pending = Future.value();
  String? notice;
  CatalogStore._(this.preferences);
  static Future<CatalogStore> open(SharedPreferences prefs) async {
    final store = CatalogStore._(prefs);
    await store._restore();
    return store;
  }

  List<CatalogEntity> all(EntityKind kind) =>
      List.unmodifiable(_data[kind] ?? []);
  CatalogEntity? byId(EntityKind kind, int id) {
    for (final row in all(kind)) {
      if (row.id == id) return row;
    }
    return null;
  }

  void dismissNotice() {
    notice = null;
    notifyListeners();
  }

  Future<void> _restore() async {
    final raw = preferences.getString(storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map ||
            decoded['schemaVersion'] != schemaVersion ||
            decoded['entities'] is! Map) {
          throw const FormatException('Неподдерживаемая версия');
        }
        final entities = decoded['entities'] as Map;
        final ids = decoded['nextIds'] is Map ? decoded['nextIds'] as Map : {};
        for (final kind in EntityKind.values) {
          final list = entities[kind.name];
          if (list is! List) throw const FormatException('Повреждённый список');
          final seen = <int>{};
          _data[kind] = list.map((e) {
            if (e is! Map) throw const FormatException('Повреждённая запись');
            final row = kind.decode(Map<String, dynamic>.from(e));
            if (row.id <= 0 || !seen.add(row.id)) {
              throw const FormatException('Некорректный ID');
            }
            return row;
          }).toList();
          final maxId = _data[kind]!.fold(
            0,
            (n, row) => row.id > n ? row.id : n,
          );
          final stored = ids[kind.name];
          _nextIds[kind] = stored is int && stored > maxId ? stored : maxId + 1;
        }
        return;
      } catch (_) {
        // Retain the damaged snapshot for diagnosis, instead of silently discarding it.
        if (!await preferences.setString('${storageKey}_backup', raw)) {
          throw StateError('Не удалось сохранить резервную копию хранилища');
        }
        notice =
            'Формат хранилища изменён или повреждён. Загружены начальные данные; прежняя копия сохранена.';
      }
    } else if (preferences.getKeys().any(
      (k) => RegExp(r'(catalog|books|authors).*_v[12]$').hasMatch(k),
    )) {
      notice =
          'Используется новая версия хранилища v3. Данные старого формата оставлены в браузере; загружен начальный каталог.';
    }
    _data = seedCatalog();
    _nextIds = {
      for (final kind in EntityKind.values)
        kind: _data[kind]!.fold(0, (n, row) => row.id > n ? row.id : n) + 1,
    };
    await _persist(_data, _nextIds);
  }

  Future<void> _persist(
    Map<EntityKind, List<CatalogEntity>> data,
    Map<EntityKind, int> nextIds,
  ) async {
    final ok = await preferences.setString(
      storageKey,
      jsonEncode({
        'schemaVersion': schemaVersion,
        'nextIds': {for (final k in EntityKind.values) k.name: nextIds[k]},
        'entities': {
          for (final k in EntityKind.values)
            k.name: data[k]!.map((r) => r.toJson()).toList(),
        },
      }),
    );
    if (!ok) {
      throw StateError(
        'Браузер не сохранил данные. Проверьте доступ к хранилищу.',
      );
    }
  }

  /// Serialize mutations, validate inside the queue, commit only after persistence succeeds.
  Future<T> transaction<T>(
    Future<T> Function(
      Map<EntityKind, List<CatalogEntity>>,
      Map<EntityKind, int>,
    )
    action,
  ) {
    final completer = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        final next = {
          for (final e in _data.entries) e.key: [...e.value],
        };
        final ids = Map<EntityKind, int>.from(_nextIds);
        final result = await action(next, ids);
        await _persist(next, ids);
        _data = next;
        _nextIds = ids;
        notifyListeners();
        completer.complete(result);
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });
    return completer.future;
  }
}
