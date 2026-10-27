import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'router.dart';
import 'repositories/book_repository.dart';
import 'repositories/in_memory_book_repository.dart';
import 'repositories/author_repository.dart';
import 'repositories/in_memory_author_repository.dart';
import 'state/book_list_notifier.dart';
import 'state/author_list_notifier.dart';

void main() {
  usePathUrlStrategy();
  runApp(
    MultiProvider(
      providers: [
        Provider<BookRepository>(
          create: (_) => InMemoryBookRepository(),
        ),
        Provider<AuthorRepository>(
          create: (_) => InMemoryAuthorRepository(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              BookListNotifier(context.read<BookRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              AuthorListNotifier(context.read<AuthorRepository>())..load(),
        ),
      ],
      child: const LibraryApp(),
    ),
  );
}

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Библиотечная система',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      routerConfig: appRouter,
    );
  }
}