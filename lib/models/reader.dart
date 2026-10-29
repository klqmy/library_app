import 'catalog_entity.dart';
import 'json_values.dart';
import 'library_card.dart';

class Reader implements CatalogEntity {
  @override
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final LibraryCard libraryCard;
  @override
  final DateTime? deletedAt;
  const Reader({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.libraryCard,
    this.deletedAt,
  });
  @override
  String get label => '$lastName $firstName';
  @override
  bool get isDeleted => deletedAt != null;
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'libraryCard': libraryCard.toJson(),
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Reader.fromJson(Map<String, dynamic> json) => Reader(
    id: jsonInt(json['id']),
    firstName: jsonString(json['firstName']),
    lastName: jsonString(json['lastName']),
    email: jsonString(json['email']),
    phone: jsonString(json['phone']),
    libraryCard: LibraryCard.fromJson(jsonMap(json['libraryCard'])),
    deletedAt: jsonDate(json['deletedAt']),
  );
}
