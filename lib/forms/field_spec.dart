import '../models/entity_kind.dart';
import '../validation/validators.dart';

enum FieldType { text, number, select, multi, date }

class FieldSpec {
  final String name;
  final String label;
  final FieldType type;
  final FieldValidator? validate;
  final EntityKind? relation;
  final String? hint;
  final bool readOnly;
  const FieldSpec(
    this.name,
    this.label, {
    this.type = FieldType.text,
    this.validate,
    this.relation,
    this.hint,
    this.readOnly = false,
  });
}

List<FieldSpec> fieldsFor(EntityKind kind) {
  final fullName = FieldSpec(
    'fullName',
    'ФИО',
    validate: (v) => Validators.text(v, min: 2, max: 200),
  );
  final country = FieldSpec(
    'country',
    'Страна',
    validate: (v) => Validators.text(v, max: 80),
  );
  return switch (kind) {
    EntityKind.books => [
      FieldSpec(
        'title',
        'Название',
        validate: (v) => Validators.text(v, min: 2, max: 200),
      ),
      FieldSpec(
        'isbn',
        'ISBN',
        validate: Validators.isbn,
        hint: 'Например, 978-5-17-090123-4',
      ),
      FieldSpec(
        'year',
        'Год издания',
        type: FieldType.number,
        validate: (v) =>
            Validators.integer(v, min: 1450, max: DateTime.now().year),
      ),
      FieldSpec(
        'pages',
        'Количество страниц',
        type: FieldType.number,
        validate: (v) => Validators.integer(v, min: 1, max: 10000),
      ),
      const FieldSpec(
        'publisherId',
        'Издательство',
        type: FieldType.select,
        relation: EntityKind.publishers,
      ),
      const FieldSpec(
        'authorIds',
        'Авторы',
        type: FieldType.multi,
        relation: EntityKind.authors,
      ),
      const FieldSpec(
        'genreIds',
        'Жанры',
        type: FieldType.multi,
        relation: EntityKind.genres,
      ),
      FieldSpec(
        'copiesTotal',
        'Всего экземпляров',
        type: FieldType.number,
        validate: (v) => Validators.integer(v, min: 1, max: 100000),
      ),
      FieldSpec(
        'copiesAvailable',
        'Доступно экземпляров',
        type: FieldType.number,
        readOnly: true,
        hint: 'Рассчитывает сервер при выдаче и возврате',
        validate: (v) => Validators.integer(v, min: 0, max: 100000),
      ),
    ],
    EntityKind.authors => [
      fullName,
      FieldSpec(
        'birthYear',
        'Год рождения',
        type: FieldType.number,
        hint: 'Необязательно',
        validate: (v) => Validators.integer(
          v,
          min: 1,
          max: DateTime.now().year,
          required: false,
        ),
      ),
      country,
    ],
    EntityKind.genres => [
      FieldSpec(
        'name',
        'Название жанра',
        validate: (v) => Validators.text(v, min: 2, max: 80),
      ),
      FieldSpec(
        'description',
        'Описание',
        validate: (v) => Validators.text(v, max: 500, required: false),
      ),
    ],
    EntityKind.publishers => [
      FieldSpec(
        'name',
        'Название издательства',
        validate: (v) => Validators.text(v, min: 2, max: 120),
      ),
      FieldSpec('city', 'Город', validate: (v) => Validators.text(v, max: 80)),
      FieldSpec(
        'foundedYear',
        'Год основания',
        type: FieldType.number,
        hint: 'Необязательно',
        validate: (v) => Validators.integer(
          v,
          min: 1400,
          max: DateTime.now().year,
          required: false,
        ),
      ),
    ],
    EntityKind.readers => [
      fullName,
      FieldSpec('email', 'Электронная почта', validate: Validators.email),
      FieldSpec('phone', 'Телефон', validate: Validators.phone),
      FieldSpec(
        'card.number',
        'Номер билета',
        validate: (v) => Validators.text(v, min: 3, max: 30),
      ),
      const FieldSpec(
        'card.issuedAt',
        'Дата выдачи',
        type: FieldType.date,
        validate: Validators.date,
        hint: 'ГГГГ-ММ-ДД',
      ),
      const FieldSpec(
        'card.expiresAt',
        'Действует до',
        type: FieldType.date,
        validate: Validators.date,
        hint: 'ГГГГ-ММ-ДД',
      ),
    ],
  };
}
