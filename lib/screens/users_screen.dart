import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/page_result.dart';
import '../repositories/library_service.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_page.dart';
import '../widgets/request_state.dart';
import 'catalog_list_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<PageResult<AppUser>> _future;
  final _drafts = <int, Role>{};
  final _busy = <int>{};
  int _page = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<LibraryService>().users(_page);
  }

  Future<void> _save(AppUser user) async {
    if (_busy.contains(user.id)) return;
    setState(() => _busy.add(user.id));
    try {
      await context.read<LibraryService>().changeRole(
        user.id,
        _drafts[user.id] ?? user.role,
      );
      if (mounted) {
        setState(() {
          _drafts.remove(user.id);
          _load();
        });
      }
    } catch (e) {
      if (mounted) await showProblem(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Пользователи и роли',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Пользователи и роли',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        FutureBuilder<PageResult<AppUser>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return RequestState(
                error: snapshot.error,
                retry: () => setState(_load),
              );
            }
            final result = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final user in result.items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 14,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 330,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text('${user.username} · ${user.email}'),
                                if (user.id ==
                                    context.read<AuthNotifier>().user?.id)
                                  const Text('Ваша учётная запись'),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: DropdownButtonFormField<Role>(
                              key: ValueKey('${user.id}:${user.role.name}'),
                              initialValue: _drafts[user.id] ?? user.role,
                              decoration: const InputDecoration(
                                labelText: 'Роль',
                              ),
                              items: [
                                for (final role in Role.values)
                                  DropdownMenuItem(
                                    value: role,
                                    child: Text(role.label),
                                  ),
                              ],
                              onChanged:
                                  user.id ==
                                          context
                                              .read<AuthNotifier>()
                                              .user
                                              ?.id ||
                                      _busy.contains(user.id)
                                  ? null
                                  : (role) => setState(
                                      () => _drafts[user.id] = role!,
                                    ),
                            ),
                          ),
                          if (_drafts[user.id] != null &&
                              _drafts[user.id] != user.role)
                            FilledButton(
                              onPressed: _busy.contains(user.id)
                                  ? null
                                  : () => _save(user),
                              child: const Text('Сохранить роль'),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: result.hasPrevious
                          ? () => setState(() {
                              _page--;
                              _load();
                            })
                          : null,
                      child: const Text('Назад'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'Страница ${result.page} из ${result.totalPages}',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: result.hasNext
                          ? () => setState(() {
                              _page++;
                              _load();
                            })
                          : null,
                      child: const Text('Вперёд'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
