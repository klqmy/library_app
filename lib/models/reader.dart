import 'catalog_entity.dart';
import 'json_values.dart';
import 'library_card.dart';

class Reader implements CatalogEntity {
  @override
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final LibraryCard? card;
  @override
  final DateTime? deletedAt;
  const Reader({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.card,
    this.deletedAt,
  });
  @override
  String get label => fullName;
  @override
  bool get isDeleted => deletedAt != null;
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'card': card?.toJson(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
  factory Reader.fromJson(Map<String, dynamic> json) => Reader(
    id: jsonInt(json['id']),
    fullName: jsonFullName(json),
    email: jsonString(json['email']),
    phone: jsonString(json['phone']),
    card: (json.containsKey('card') ? json['card'] : json['libraryCard']) is Map
        ? LibraryCard.fromJson(
            jsonMap(
              json.containsKey('card') ? json['card'] : json['libraryCard'],
            ),
          )
        : null,
    deletedAt: jsonDate(json['deletedAt']),
  );
}
