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
          country: 'Россия',
          city: i == 2 ? 'Санкт-Петербург' : 'Москва',
          genreIds: {
            ...seedBooks
                .where((b) => b.publisherId == i + 1)
                .expand((b) => b.genreIds),
            if (!seedBooks.any((b) => b.publisherId == i + 1)) 1,
          }.toList(),
        ),
    ],
    EntityKind.readers: [
      for (var i = 1; i <= 12; i++)
        Reader(
          id: i,
          firstName: ['Анна', 'Дмитрий', 'Мария', 'Иван'][(i - 1) % 4],
          lastName: ['Волкова', 'Смирнов', 'Соколова', 'Петров'][(i - 1) % 4],
          email: 'reader$i@example.org',
          phone: '+7 900 000 ${i.toString().padLeft(4, '0')}',
          libraryCard: LibraryCard(
            id: i,
            number: 'LB-${i.toString().padLeft(4, '0')}',
            issuedAt: DateTime(2025, 9, 1),
            expiresAt: DateTime(2028, 9, 1),
          ),
        ),
    ],
  };
}
