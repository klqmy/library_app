int jsonInt(Object? value, [int fallback = 0]) =>
    value is int ? value : int.tryParse('$value') ?? fallback;
int? jsonOptionalInt(Object? value) =>
    value is int ? value : int.tryParse('$value');
String jsonString(Object? value) => value is String ? value : '';
List<int> jsonIds(Object? value) => value is List
    ? value.map((e) => jsonInt(e, -1)).where((e) => e > 0).toSet().toList()
    : [];
DateTime? jsonDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
Map<String, dynamic> jsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

String jsonFullName(Map<String, dynamic> json) => json.containsKey('fullName')
    ? jsonString(json['fullName'])
    : [
        jsonString(json['lastName']),
        jsonString(json['firstName']),
      ].where((part) => part.trim().isNotEmpty).join(' ').trim();

int jsonRelationId(Map<String, dynamic> json, String key, String expanded) =>
    jsonOptionalInt(json[key]) ?? jsonInt(jsonMap(json[expanded])['id']);

List<int> jsonRelationIds(
  Map<String, dynamic> json,
  String key,
  String expanded,
) => json[key] is List
    ? jsonIds(json[key])
    : jsonIds(
        (json[expanded] is List ? json[expanded] as List : [])
            .map((item) => jsonMap(item)['id'])
            .toList(),
      );

DateTime? jsonCardDate(Object? value) {
  final date = jsonDate(value);
  if (date == null || date.isUtc) return date;
  return DateTime.utc(
    date.year,
    date.month,
    date.day,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}
