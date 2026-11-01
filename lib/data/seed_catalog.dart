import '../models/catalog_entity.dart';
import '../models/entity_kind.dart';
import '../models/genre.dart';
import '../models/publisher.dart';
import '../models/reader.dart';
import '../models/library_card.dart';
import 'seed_books.dart';
import 'seed_authors.dart';

Map<EntityKind, List<CatalogEntity>> seedCatalog() {
  const names = [
    'Роман',
    'Повесть',
    'Детектив',
    'Поэзия',
    'Сатира',
    'Драма',
    'Любовный',
    'Магический реализм',
    'Приключения',
    'Абсурд',
    'Исторический роман',
  ];
  const publishers = [
    'АСТ',
    'Эксмо',
    'Азбука',
    'Просвещение',
    'Рипол Классик',
    'Иностранка',
    'Альпина',
    'Речь',
    'МИФ',
  ];
  return {
    EntityKind.books: [...seedBooks],
    EntityKind.authors: [...seedAuthors],
    EntityKind.genres: [
      for (var i = 0; i < names.length; i++)
        Genre(
          id: i + 1,
          name: names[i],
          description: 'Книги жанра «${names[i]}».',
        ),
    ],
    EntityKind.publishers: [
      for (var i = 0; i < publishers.length; i++)
        Publisher(
          id: i + 1,
          name: publishers[i],
          city: i == 2 ? 'Санкт-Петербург' : 'Москва',
          foundedYear: i < 3 ? [1990, 1991, 1995][i] : null,
        ),
    ],
    EntityKind.readers: [
      for (var i = 1; i <= 12; i++)
        Reader(
          id: i,
          fullName: [
            'Волкова Анна',
            'Смирнов Дмитрий',
            'Соколова Мария',
            'Петров Иван',
          ][(i - 1) % 4],
          email: 'reader$i@example.org',
          phone: '+7 900 000 ${i.toString().padLeft(4, '0')}',
          card: LibraryCard(
            id: i,
            number: 'LB-${i.toString().padLeft(4, '0')}',
            issuedAt: DateTime.utc(2025, 9, 1),
            expiresAt: DateTime.utc(2028, 9, 1),
          ),
        ),
    ],
  };
}
