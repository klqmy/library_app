import 'catalog_entity.dart';
import 'book.dart';
import 'author.dart';
import 'genre.dart';
import 'publisher.dart';
import 'reader.dart';

enum EntityKind {
  books('Книги', 'Книга'),
  authors('Авторы', 'Автор'),
  genres('Жанры', 'Жанр'),
  publishers('Издательства', 'Издательство'),
  readers('Читатели', 'Читатель');

  final String title;
  final String singular;
  const EntityKind(this.title, this.singular);
  String get path => '/$name';
  CatalogEntity decode(Map<String, dynamic> json) => switch (this) {
    books => Book.fromJson(json),
    authors => Author.fromJson(json),
    genres => Genre.fromJson(json),
    publishers => Publisher.fromJson(json),
    readers => Reader.fromJson(json),
  };
}
