import 'package:flutter/material.dart';
import '../models/catalog_entity.dart';
import '../repositories/catalog_repository.dart';
import 'request_state.dart';

class LoanDialog extends StatefulWidget {
  final CatalogRepository repository;
  final int bookId;
  const LoanDialog({super.key, required this.repository, required this.bookId});
  @override
  State<LoanDialog> createState() => _LoanDialogState();
}

class _LoanDialogState extends State<LoanDialog> {
  late Future<List<CatalogEntity>> _readers;
  int? _reader;
  bool _saving = false;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _readers = widget.repository.readerChoices();
  }

  Future<void> _save() async {
    if (_saving || _reader == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.issueLoan(widget.bookId, _reader!, 14);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Выдать книгу'),
    content: SizedBox(
      width: 440,
      child: FutureBuilder<List<CatalogEntity>>(
        future: _readers,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return RequestState(
              error: snapshot.error,
              retry: () => setState(() {
                _readers = widget.repository.readerChoices();
              }),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Срок выдачи: 14 дней'),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Читатель'),
                isExpanded: true,
                items: [
                  for (final r in snapshot.data!)
                    DropdownMenuItem(value: r.id, child: Text(r.label)),
                ],
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _reader = id),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    _error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _saving || _reader == null ? null : _save,
        child: Text(_saving ? 'Сохранение…' : 'Выдать'),
      ),
    ],
  );
}
