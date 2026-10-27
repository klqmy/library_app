import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../repositories/author_repository.dart';
import '../models/author.dart';

class AuthorCardScreen extends StatelessWidget {
  final int authorId;
  const AuthorCardScreen({super.key, required this.authorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка автора'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/authors')),
      ),
      body: FutureBuilder<Author?>(
        future: context.read<AuthorRepository>().findById(authorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          final author = snapshot.data;
          if (author == null) return const Center(child: Text('Автор не найден'));

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
                      Text(author.fullName, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 16),
                      Text('Страна: ${author.country}'),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(onPressed: () => context.go('/authors'), child: const Text('Назад к списку')),
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