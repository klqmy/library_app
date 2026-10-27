import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../repositories/book_repository.dart';
import '../models/book.dart';

class BookCardScreen extends StatelessWidget {
  final int bookId;
  const BookCardScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка книги'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/books')),
      ),
      body: FutureBuilder<Book?>(
        future: context.read<BookRepository>().findById(bookId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          final book = snapshot.data;
          if (book == null) return const Center(child: Text('Книга не найдена'));

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(book.title, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 16),
                      Text('ISBN: ${book.isbn}'),
                      Text('Год издания: ${book.year}'),
                      Text('Страниц: ${book.pages}'),
                      Text('Всего экземпляров: ${book.copiesTotal}'),
                      Text('Доступно: ${book.copiesAvailable}'),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(onPressed: () => context.go('/books'), child: const Text('Назад к списку')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}