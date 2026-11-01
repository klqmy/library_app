typedef FieldValidator = String? Function(String? value);

class Validators {
  static String? text(
    String? value, {
    int min = 1,
    int max = 120,
    bool required = true,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return required ? 'Обязательное поле' : null;
    if (text.length < min) return 'Минимум $min символа';
    if (text.length > max) return 'Максимум $max символов';
    return null;
  }

  static String? integer(
    String? value, {
    int min = 0,
    int max = 100000,
    bool required = true,
  }) {
    if ((value ?? '').trim().isEmpty) {
      return required ? 'Обязательное поле' : null;
    }
    final number = int.tryParse(value!.trim());
    if (number == null) return 'Введите целое число';
    return number < min || number > max ? 'Число от $min до $max' : null;
  }

  static String normalizeIsbn(String value) =>
      value.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
  static String? isbn(String? value) {
    final error = text(value, max: 32);
    if (error != null) return error;
    final normalized = normalizeIsbn(value!);
    return RegExp(r'^(\d{13}|\d{9}[\dX])$').hasMatch(normalized)
        ? null
        : 'ISBN: 10 или 13 знаков, дефисы допустимы';
  }

  static String? email(String? value) {
    final error = text(value, max: 254);
    if (error != null) return error;
    return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value!.trim())
        ? null
        : 'Введите корректный адрес почты';
  }

  static String? phone(String? value) {
    final error = text(value, max: 25);
    if (error != null) return error;
    final v = value!.trim();
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^\+?[\d ()-]+$').hasMatch(v) &&
            digits.length >= 10 &&
            digits.length <= 15
        ? null
        : 'Телефон: от 10 до 15 цифр';
  }

  static DateTime? parseDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final date = DateTime.tryParse(value);
    return date != null && date.toIso8601String().substring(0, 10) == value
        ? date
        : null;
  }

  static String? date(String? value) =>
      parseDate(value ?? '') == null ? 'Дата в формате ГГГГ-ММ-ДД' : null;
}
