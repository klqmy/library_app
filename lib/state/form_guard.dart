import 'package:flutter/material.dart';

class FormGuard {
  Object? owner;
  bool dirty = false;
  Future<bool>? _dialog;
  void attach(Object token) {
    owner = token;
    dirty = false;
  }

  void detach(Object token) {
    if (owner == token) {
      owner = null;
      dirty = false;
    }
  }

  Future<bool> canLeave(BuildContext context) async {
    if (!dirty) return true;
    if (_dialog != null) return _dialog!;
    _dialog = showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text(
          'Изменения в форме ещё не сохранены. Покинуть страницу?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Выйти без сохранения'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
    final leave = await _dialog!;
    _dialog = null;
    if (leave) dirty = false;
    return leave;
  }
}
