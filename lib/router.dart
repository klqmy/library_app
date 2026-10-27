import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/book_list_screen.dart';
import 'screens/book_card_screen.dart';
import 'screens/author_list_screen.dart';
import 'screens/author_card_screen.dart';
import 'screens/not_found_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/books',
      builder: (context, state) => const BookListScreen(),
    ),
    GoRoute(
      path: '/books/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id'] ?? '0');
        return BookCardScreen(bookId: id);
      },
    ),
    GoRoute(
      path: '/authors',
      builder: (context, state) => const AuthorListScreen(),
    ),
    GoRoute(
      path: '/authors/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id'] ?? '0');
        return AuthorCardScreen(authorId: id);
      },
    ),
  ],
  errorBuilder: (context, state) =>
      NotFoundScreen(location: state.uri.toString()),
);