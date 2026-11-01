import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/loan.dart';
import '../models/page_result.dart';
import '../repositories/library_service.dart';
import '../widgets/app_page.dart';
import '../widgets/request_state.dart';
import 'catalog_list_screen.dart';

class LoansScreen extends StatefulWidget {
  final bool own;
  const LoansScreen({super.key, required this.own});
  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  late Future<PageResult<Loan>> _future;
  final _busy = <int>{};
  int _page = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<LibraryService>().loans(_page);
  }

  Future<void> _action(Loan loan) async {
    if (_busy.contains(loan.id)) return;
    setState(() => _busy.add(loan.id));
    try {
      final service = context.read<LibraryService>();
      if (widget.own) {
        await service.extend(loan.id);
      } else {
        await service.returnLoan(loan.id);
      }
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) await showProblem(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(loan.id));
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  @override
  Widget build(BuildContext context) => AppPage(
    title: widget.own ? 'Мои выдачи' : 'Рабочее место библиотекаря',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              widget.own ? 'Мои выдачи' : 'Рабочее место библиотекаря',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (!widget.own)
              FilledButton.icon(
                onPressed: () => context.go('/books'),
                icon: const Icon(Icons.menu_book),
                label: const Text('Открыть каталог для выдачи'),
              ),
            IconButton(
              onPressed: () => setState(_load),
              tooltip: 'Обновить',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FutureBuilder<PageResult<Loan>>(
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
                if (result.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text('Выдач пока нет.'),
                  ),
                for (final loan in result.items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.book,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (!widget.own) Text('Читатель: ${loan.reader}'),
                          const SizedBox(height: 8),
                          Text(
                            'Выдано: ${_date(loan.issuedAt)} · Срок: ${_date(loan.dueAt)}',
                          ),
                          Text(switch (loan.status) {
                            'returned' => 'Книга возвращена',
                            'overdue' => 'Срок возврата истёк',
                            _ => 'Книга на руках',
                          }),
                          if (!loan.returned)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: OutlinedButton.icon(
                                onPressed: _busy.contains(loan.id)
                                    ? null
                                    : () => _action(loan),
                                icon: Icon(
                                  widget.own
                                      ? Icons.event_repeat
                                      : Icons.assignment_return_outlined,
                                ),
                                label: Text(
                                  widget.own
                                      ? 'Продлить на 7 дней'
                                      : 'Принять возврат',
                                ),
                              ),
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
