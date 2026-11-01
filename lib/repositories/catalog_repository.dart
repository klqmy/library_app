import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/entity_kind.dart';
import '../models/reader.dart';
import '../models/json_values.dart';
import '../models/page_result.dart';
import '../forms/field_spec.dart';
import '../validation/validators.dart';
import 'catalog_store.dart';

typedef FieldErrors = ValidationException;

Map<String, dynamic> formData(CatalogEntity row) {
  final data = row.toJson();
  if (row is Reader) {
    data['card.number'] = row.card?.number ?? '';
    data['card.issuedAt'] =
        row.card?.issuedAt?.toUtc().toIso8601String().substring(0, 10) ?? '';
    data['card.expiresAt'] =
        row.card?.expiresAt?.toUtc().toIso8601String().substring(0, 10) ?? '';
  }
  return data;
}

class CatalogRepository {
  final CatalogStore store;
  final EntityKind kind;
  CatalogRepository(this.store, this.kind);
  List<CatalogEntity> get all => store.all(kind);
  CatalogEntity? byId(int id) => store.byId(kind, id);
  List<CatalogEntity> options(EntityKind relation) =>
      store.all(relation).where((r) => !r.isDeleted).toList();
  List<CatalogEntity> genresForPublisher(int id) =>
      store.genresForPublisher(id);
  int? references(int id) => store.references(id);

  Future<PageResult<CatalogEntity>> find(
    CatalogQuery query, {
    RequestToken? cancel,
  }) async {
    final data = await store.api.get(
      kind.path,
      query: query.toApi(kind),
      cancel: cancel,
    );
    final rows = store.decodeRows(kind, data);
    return PageResult(
      items: rows,
      page: (data['page'] as num).toInt(),
      size: (data['size'] as num).toInt(),
      total: (data['total'] as num).toInt(),
    );
  }

  Map<String, String> validate(Map<String, dynamic> data, {int? id}) {
    final errors = <String, String>{};
    for (final field in fieldsFor(kind)) {
      if (field.readOnly) continue;
      if (field.relation != null) {
        final selected = field.type == FieldType.multi
            ? jsonIds(data[field.name])
            : [jsonInt(data[field.name])];
        final allowed = options(field.relation!).map((e) => e.id).toSet();
        if (selected.isEmpty || selected.any((id) => !allowed.contains(id))) {
          errors[field.name] = field.type == FieldType.multi
              ? 'Выберите хотя бы одно доступное значение'
              : 'Выберите доступное значение';
        }
      } else {
        final error = field.validate?.call(data[field.name]?.toString());
        if (error != null) errors[field.name] = error;
      }
    }
    if (kind == EntityKind.readers) {
      final issued = Validators.parseDate('${data['card.issuedAt'] ?? ''}');
      final expires = Validators.parseDate('${data['card.expiresAt'] ?? ''}');
      if (issued != null && issued.isAfter(DateTime.now())) {
        errors['card.issuedAt'] = 'Дата выдачи не может быть в будущем';
      }
      if (issued != null && expires != null && !expires.isAfter(issued)) {
        errors['card.expiresAt'] =
            'Срок действия должен быть позже даты выдачи';
      }
    }
    // Уникальность и состояние связанных записей проверяет сервер (422/409).
    return errors;
  }

  Future<CatalogEntity> save(Map<String, dynamic> values, {int? id}) async {
    final errors = validate(values, id: id);
    if (errors.isNotEmpty) throw FieldErrors(errors);
    final json = <String, dynamic>{};
    for (final field in fieldsFor(kind)) {
      if (field.readOnly || field.name.startsWith('card.')) continue;
      final value = values[field.name];
      json[field.name] = field.type == FieldType.number
          ? jsonOptionalInt(value)
          : value is String
          ? value.trim()
          : value;
    }
    if (kind == EntityKind.readers) {
      json['email'] = '${json['email']}'.toLowerCase();
      json['card'] = {
        'number': '${values['card.number'] ?? ''}'.trim(),
        'issuedAt': jsonCardDate(values['card.issuedAt'])?.toIso8601String(),
        'expiresAt': jsonCardDate(values['card.expiresAt'])?.toIso8601String(),
      };
    }
    final data = id == null
        ? await store.api.post(kind.path, data: json)
        : await store.api.put('${kind.path}/$id', data: json);
    final row = kind.decode(Map<String, dynamic>.from(data));
    store.changed(kind);
    return row;
  }

  Future<void> deleteMany(Set<int> selected, {bool hard = false}) async {
    if (selected.isEmpty) return;
    try {
      if (hard || selected.length == 1) {
        for (final id in selected) {
          await store.api.delete(
            '${kind.path}/$id',
            query: {if (hard) 'hard': true},
          );
        }
      } else {
        await store.api.post(
          '${kind.path}/bulk-delete',
          data: {'ids': selected.toList()},
        );
      }
    } finally {
      // При частичном успехе последовательного удаления список тоже обновляется.
      store.changed(kind);
    }
  }

  Future<void> restore(int id) async {
    await store.api.post('${kind.path}/$id/restore');
    store.changed(kind);
  }

  Future<List<CatalogEntity>> readerChoices() =>
      store.reference(EntityKind.readers);
  Future<void> issueLoan(int bookId, int readerId, int days) async {
    await store.api.post(
      '/loans',
      data: {'bookId': bookId, 'readerId': readerId, 'days': days},
    );
    await store.fetchById(EntityKind.books, bookId);
    store.changed(EntityKind.books);
  }
}
