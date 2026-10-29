int jsonInt(Object? value, [int fallback = 0]) =>
    value is int ? value : int.tryParse('$value') ?? fallback;
String jsonString(Object? value) => value is String ? value : '';
List<int> jsonIds(Object? value) => value is List
    ? value.map((e) => jsonInt(e, -1)).where((e) => e > 0).toSet().toList()
    : [];
DateTime? jsonDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
Map<String, dynamic> jsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
