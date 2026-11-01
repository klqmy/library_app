import 'json_values.dart';

class LibraryCard {
  final int id;
  final String number;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  const LibraryCard({
    required this.id,
    required this.number,
    this.issuedAt,
    this.expiresAt,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'issuedAt': issuedAt?.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };
  factory LibraryCard.fromJson(Map<String, dynamic> json) => LibraryCard(
    id: jsonInt(json['id']),
    number: jsonString(json['number']),
    issuedAt: jsonCardDate(json['issuedAt']),
    expiresAt: jsonCardDate(json['expiresAt']),
  );
}
