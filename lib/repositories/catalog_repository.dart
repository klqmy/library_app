import '../models/catalog_entity.dart';
import '../models/entity_kind.dart';
import '../models/book.dart';
import '../models/publisher.dart';
import '../models/reader.dart';
import '../models/json_values.dart';
import '../forms/field_spec.dart';
import '../validation/validators.dart';
import 'catalog_store.dart';

class FieldErrors implements Exception {
  final Map<String, String> errors;
  FieldErrors(this.errors);
}

class RelationConflict implements Exception {
  final int count;
  RelationConflict(this.count);
  @override
  String toString() =>
      'Нельзя удалить запись: связанных книг — $count. Сначала измените или удалите связанные книги (включая корзину).';
}

Map<String, dynamic> formData(CatalogEntity row) {
  final data = row.toJson();
  if (row is Reader) {
    data['cardNumber'] = row.libraryCard.number;
    data['issuedAt'] =
        row.libraryCard.issuedAt?.toIso8601String().substring(0, 10) ?? '';
    data['expiresAt'] =
        row.libraryCard.expiresAt?.toIso8601String().substring(0, 10) ?? '';
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
  Map<String, String> validate(Map<String, dynamic> data, {int? id}) {
    final errors = <String, String>{};
    for (final field in fieldsFor(kind)) {
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
    if (kind == EntityKind.books) {
      final isbn = Validators.normalizeIsbn('${data['isbn'] ?? ''}');
      if (all.whereType<Book>().any(
        (b) => b.id != id && Validators.normalizeIsbn(b.isbn) == isbn,
      )) {
        errors['isbn'] = 'Книга с таким ISBN уже существует';
      }
      if (jsonInt(data['copiesAvailable']) > jsonInt(data['copiesTotal'])) {
        errors['copiesAvailable'] = 'Доступно не больше общего количества';
      }
      final publisher = store.byId(
        EntityKind.publishers,
        jsonInt(data['publisherId']),
      );
      if (publisher is Publisher &&
          jsonIds(
            data['genreIds'],
          ).any((g) => !publisher.genreIds.contains(g))) {
        errors['genreIds'] = 'Выберите жанры из направлений издательства';
      }
    }
    if (kind == EntityKind.publishers && id != null) {
      final removed = store
          .all(EntityKind.books)
          .whereType<Book>()
          .where((b) => b.publisherId == id)
          .expand((b) => b.genreIds)
          .where((g) => !jsonIds(data['genreIds']).contains(g));
      if (removed.isNotEmpty) {
        errors['genreIds'] =
            'Эти направления используются книгами издательства';
      }
    }
    if (kind == EntityKind.readers) {
      final email = '${data['email'] ?? ''}'.trim().toLowerCase();
      final number = '${data['cardNumber'] ?? ''}'.trim().toLowerCase();
      if (all.whereType<Reader>().any(
        (r) => r.id != id && r.email.toLowerCase() == email,
      )) {
        errors['email'] = 'Читатель с такой почтой уже существует';
      }
      if (all.whereType<Reader>().any(
        (r) => r.id != id && r.libraryCard.number.toLowerCase() == number,
      )) {
        errors['cardNumber'] = 'Номер билета уже занят';
      }
      final issued = Validators.parseDate('${data['issuedAt'] ?? ''}');
      final expires = Validators.parseDate('${data['expiresAt'] ?? ''}');
      if (issued != null && issued.isAfter(DateTime.now())) {
        errors['issuedAt'] = 'Дата выдачи не может быть в будущем';
      }
      if (issued != null && expires != null && !expires.isAfter(issued)) {
        errors['expiresAt'] = 'Срок действия должен быть позже даты выдачи';
      }
    }
    return errors;
  }

  Future<CatalogEntity> save(Map<String, dynamic> values, {int? id}) =>
      store.transaction((data, ids) async {
        final errors = validate(values, id: id);
        if (errors.isNotEmpty) throw FieldErrors(errors);
        final rows = data[kind]!;
        final index = id == null ? -1 : rows.indexWhere((e) => e.id == id);
        if (id != null && index < 0) throw StateError('Запись не найдена');
        final nextId = id ?? ids[kind]!;
        final json = Map<String, dynamic>.from(values);
        for (final field in fieldsFor(kind)) {
          if (json[field.name] is String) {
            json[field.name] = (json[field.name] as String).trim();
          }
          if (field.type == FieldType.number) {
            json[field.name] = jsonInt(json[field.name]);
          }
        }
        json['id'] = nextId;
        json['deletedAt'] = index >= 0
            ? rows[index].deletedAt?.toIso8601String()
            : null;
        if (kind == EntityKind.readers) {
          json['email'] = '${json['email']}'.toLowerCase();
          json['libraryCard'] = {
            'id': nextId,
            'number': json['cardNumber'],
            'issuedAt': json['issuedAt'],
            'expiresAt': json['expiresAt'],
          };
        }
        final row = kind.decode(json);
        if (index >= 0) {
          rows[index] = row;
        } else {
          rows.add(row);
          ids[kind] = nextId + 1;
        }
        return row;
      });
  int references(int id) => switch (kind) {
    EntityKind.publishers =>
      store
          .all(EntityKind.books)
          .whereType<Book>()
          .where((b) => b.publisherId == id)
          .length,
    EntityKind.authors =>
      store
          .all(EntityKind.books)
          .whereType<Book>()
          .where((b) => b.authorIds.contains(id))
          .length,
    EntityKind.genres =>
      store
          .all(EntityKind.books)
          .whereType<Book>()
          .where((b) => b.genreIds.contains(id))
          .length,
    _ => 0,
  };
  Future<void> deleteMany(Set<int> selected, {bool hard = false}) =>
      store.transaction((data, ids) async {
        for (final id in selected) {
          final count = references(id);
          if (count > 0) throw RelationConflict(count);
        }
        if (kind == EntityKind.genres) {
          for (final publisher in store.all(EntityKind.publishers).whereType<Publisher>()) {
            if (publisher.genreIds.isNotEmpty && publisher.genreIds.every(selected.contains)) {
              throw StateError('Нельзя удалить все направления издательства «${publisher.name}». Сначала добавьте другое направление.');
            }
          }
        }
        final rows = data[kind]!;
        if (hard) {
          rows.removeWhere((r) => selected.contains(r.id));
        } else {
          for (var i = 0; i < rows.length; i++) {
            if (selected.contains(rows[i].id)) {
              rows[i] = kind.decode({
                ...rows[i].toJson(),
                'deletedAt': DateTime.now().toIso8601String(),
              });
            }
          }
        }
        // Removing an unused genre also removes it from publisher directions.
        if (kind == EntityKind.genres) {
          data[EntityKind.publishers] = data[EntityKind.publishers]!
              .map(
                (p) => EntityKind.publishers.decode({
                  ...p.toJson(),
                  'genreIds': jsonIds(
                    p.toJson()['genreIds'],
                  ).where((g) => !selected.contains(g)).toList(),
                }),
              )
              .toList();
        }
      });
  Future<void> restore(int id) => store.transaction((data, ids) async {
    final rows = data[kind]!;
    final index = rows.indexWhere((r) => r.id == id);
    if (index < 0) throw StateError('Запись не найдена');
    final errors = validate(formData(rows[index]), id: id);
    if (errors.isNotEmpty) {
      throw StateError(
        'Перед восстановлением исправьте запись: ${errors.values.join('; ')}',
      );
    }
    rows[index] = kind.decode({...rows[index].toJson(), 'deletedAt': null});
  });
}
