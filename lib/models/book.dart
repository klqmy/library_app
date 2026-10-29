import 'catalog_entity.dart';
import 'json_values.dart';

class Book implements CatalogEntity {
  @override
  final int id;
  final String title;
  final String isbn;
  final int year;
  final int pages;
  final int publisherId;
  final List<int> authorIds;
  final List<int> genreIds;
  final int copiesTotal;
  final int copiesAvailable;
  @override
  final DateTime? deletedAt;

  const Book({
    required this.id,
    required this.title,
    required this.isbn,
    required this.year,
    required this.pages,
    required this.publisherId,
    required this.authorIds,
    required this.genreIds,
    required this.copiesTotal,
    required this.copiesAvailable,
    this.deletedAt,
  });

  @override
  String get label => title;

  @override
  bool get isDeleted => deletedAt != null;

  Book copyWith({
    String? title,
    String? isbn,
    int? year,
    int? pages,
    int? publisherId,
    List<int>? authorIds,
    List<int>? genreIds,
    int? copiesTotal,
    int? copiesAvailable,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      isbn: isbn ?? this.isbn,
      year: year ?? this.year,
      pages: pages ?? this.pages,
      publisherId: publisherId ?? this.publisherId,
      authorIds: authorIds ?? this.authorIds,
      genreIds: genreIds ?? this.genreIds,
      copiesTotal: copiesTotal ?? this.copiesTotal,
      copiesAvailable: copiesAvailable ?? this.copiesAvailable,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isbn': isbn,
    'year': year,
    'pages': pages,
    'publisherId': publisherId,
    'authorIds': authorIds,
    'genreIds': genreIds,
    'copiesTotal': copiesTotal,
    'copiesAvailable': copiesAvailable,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: jsonInt(json['id']),
    title: jsonString(json['title']),
    isbn: jsonString(json['isbn']),
    year: jsonInt(json['year']),
    pages: jsonInt(json['pages']),
    publisherId: jsonInt(json['publisherId']),
    authorIds: jsonIds(json['authorIds']),
    genreIds: jsonIds(json['genreIds']),
    copiesTotal: jsonInt(json['copiesTotal']),
    copiesAvailable: jsonInt(json['copiesAvailable']),
    deletedAt: jsonDate(json['deletedAt']),
  );
}
