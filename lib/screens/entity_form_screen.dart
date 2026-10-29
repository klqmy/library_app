import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/catalog_entity.dart';
import '../models/entity_kind.dart';
import '../models/publisher.dart';
import '../models/json_values.dart';
import '../forms/field_spec.dart';
import '../repositories/catalog_store.dart';
import '../repositories/catalog_repository.dart';
import '../state/form_guard.dart';
import '../widgets/app_page.dart';
import 'catalog_list_screen.dart';
import 'not_found_screen.dart';

/// One metadata-driven form handles creation and editing of every entity.
class EntityFormScreen extends StatefulWidget {
  final EntityKind kind;
  final int? id;
  const EntityFormScreen({super.key, required this.kind, this.id});
  bool get isEditing => id != null;
  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _data = <String, dynamic>{};
  final _token = Object();
  final _errors = <String, String>{};
  late final FormGuard _guard;
  late final CatalogRepository _repo;
  bool _saving = false;
  bool _submitted = false;
  bool _missing = false;
  String? _cascadeNote;
  List<FieldSpec> get fields => fieldsFor(widget.kind);
  @override
  void initState() {
    super.initState();
    _guard = context.read<FormGuard>()..attach(_token);
    _repo = CatalogRepository(context.read<CatalogStore>(), widget.kind);
    final row = widget.id == null ? null : _repo.byId(widget.id!);
    _missing = widget.id != null && row == null;
    if (row != null) _data.addAll(formData(row));
    for (final field in fields) {
      if (field.type == FieldType.multi) {
        _data[field.name] = jsonIds(_data[field.name]);
      } else if (field.type != FieldType.select) {
        _controllers[field.name] = TextEditingController(
          text: '${_data[field.name] ?? ''}',
        );
      }
    }
  }

  @override
  void dispose() {
    _guard.detach(_token);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() {
    _errors.clear();
    if (!_guard.dirty) setState(() => _guard.dirty = true);
  }

  Map<String, dynamic> _values() => {
    ..._data,
    for (final e in _controllers.entries) e.key: e.value.text,
  };
  String? _error(FieldSpec field) =>
      _errors[field.name] ??
      _repo.validate(_values(), id: widget.id)[field.name];
  List<CatalogEntity> _options(FieldSpec field) {
    var rows = _repo.options(field.relation!);
    if (widget.kind == EntityKind.books && field.name == 'genreIds') {
      final publisher = _repo.store.byId(
        EntityKind.publishers,
        jsonInt(_data['publisherId']),
      );
      rows = publisher is Publisher
          ? rows.where((g) => publisher.genreIds.contains(g.id)).toList()
          : [];
    }
    return rows;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final row = await _repo.save(_values(), id: widget.id);
      if (!mounted) return;
      setState(() {
        _guard.dirty = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Изменения сохранены' : 'Запись создана',
          ),
        ),
      );
      context.go('${widget.kind.path}/${row.id}');
    } on FieldErrors catch (e) {
      if (mounted) {
        setState(() {
          _errors.addAll(e.errors);
          _saving = false;
        });
        _formKey.currentState!.validate();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        await showProblem(context, e);
      }
    }
  }

  Widget _field(FieldSpec field) {
    if (field.type == FieldType.select) {
      final rows = _options(field);
      final value = jsonInt(_data[field.name], -1);
      return DropdownButtonFormField<int>(
        key: ValueKey('${field.name}:$value'),
        initialValue: rows.any((r) => r.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: field.label),
        items: rows
            .map((r) => DropdownMenuItem(value: r.id, child: Text(r.label)))
            .toList(),
        validator: (_) => _error(field),
        onChanged: _saving
            ? null
            : (v) {
                _changed();
                setState(() {
                  _data[field.name] = v;
                  if (widget.kind == EntityKind.books &&
                      field.name == 'publisherId') {
                    final publisher = _repo.store.byId(
                      EntityKind.publishers,
                      v ?? -1,
                    );
                    final selected = jsonIds(_data['genreIds']);
                    final kept = publisher is Publisher
                        ? selected.where(publisher.genreIds.contains).toList()
                        : <int>[];
                    _data['genreIds'] = kept;
                    _cascadeNote =
                        'Показаны жанры выбранного издательства.${kept.length < selected.length ? ' Несовместимые жанры сняты.' : ''}';
                  }
                });
              },
      );
    }
    if (field.type == FieldType.multi) {
      final rows = _options(field);
      final selected = jsonIds(_data[field.name]);
      return FormField<List<int>>(
        key: ValueKey(
          '${field.name}:${selected.join(',')}:${rows.map((r) => r.id).join(',')}',
        ),
        initialValue: selected,
        validator: (_) => _error(field),
        builder: (state) => InputDecorator(
          decoration: InputDecoration(
            labelText: field.label,
            errorText: state.errorText,
            helperText:
                widget.kind == EntityKind.books && field.name == 'genreIds'
                ? (_cascadeNote ??
                      (_data['publisherId'] == null
                          ? 'Сначала выберите издательство'
                          : 'Жанры выбранного издательства'))
                : 'Можно выбрать несколько значений',
          ),
          child: rows.isEmpty
              ? const Text(
                  'Нет доступных значений. Заполните справочник или выберите издательство.',
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final row in rows)
                      FilterChip(
                        label: Text(row.label),
                        selected: selected.contains(row.id),
                        onSelected: _saving
                            ? null
                            : (on) {
                                final next = [...selected];
                                on ? next.add(row.id) : next.remove(row.id);
                                state.didChange(next);
                                _changed();
                                setState(() => _data[field.name] = next);
                              },
                      ),
                  ],
                ),
        ),
      );
    }
    return TextFormField(
      controller: _controllers[field.name],
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        suffixIcon: field.type == FieldType.date
            ? const Icon(Icons.calendar_today, size: 18)
            : null,
      ),
      maxLines: field.name == 'description' ? 3 : 1,
      keyboardType: field.type == FieldType.number
          ? TextInputType.number
          : field.name == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      validator: (_) => _error(field),
      onChanged: (_) {
        _changed();
        if (_submitted) _formKey.currentState?.validate();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CatalogStore>();
    if (_missing) {
      return NotFoundScreen(location: '${widget.kind.path}/${widget.id}/edit');
    }
    return PopScope<Object?>(
      canPop: !_guard.dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _guard.canLeave(context);
        if (!context.mounted || !leave) return;
        context.go(widget.kind.path);
      },
      child: AppPage(
        title:
            '${widget.isEditing ? 'Редактирование' : 'Создание'} · ${widget.kind.singular}',
        backPath: widget.kind.path,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEditing ? 'Изменить запись' : 'Новая запись',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(widget.kind.title),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (c, constraints) {
                          final gap = 20.0;
                          final half = constraints.maxWidth >= 650
                              ? (constraints.maxWidth - gap) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: gap,
                            runSpacing: 22,
                            children: [
                              for (final field in fields) ...[
                                if (field.name == 'cardNumber')
                                  SizedBox(
                                    width: constraints.maxWidth,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Text(
                                        'Читательский билет',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ),
                                  ),
                                SizedBox(
                                  width:
                                      field.type == FieldType.multi ||
                                          field.name == 'description'
                                      ? constraints.maxWidth
                                      : half,
                                  child: _field(field),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              widget.isEditing
                                  ? 'Сохранить изменения'
                                  : 'Создать',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => context.go(widget.kind.path),
                            child: const Text('Отмена'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
