class Loan {
  final int id;
  final String book;
  final String reader;
  final DateTime issuedAt;
  final DateTime dueAt;
  final String status;
  const Loan(
    this.id,
    this.book,
    this.reader,
    this.issuedAt,
    this.dueAt,
    this.status,
  );
  bool get returned => status == 'returned';
  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
    (json['id'] as num).toInt(),
    (json['book'] as Map?)?['title']?.toString() ?? 'Книга не найдена',
    (json['reader'] as Map?)?['fullName']?.toString() ?? 'Читатель не найден',
    DateTime.parse(json['issuedAt'] as String),
    DateTime.parse(json['dueAt'] as String),
    json['status'] as String? ?? 'active',
  );
}
