import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'repositories/catalog_store.dart';
import 'state/form_guard.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  try {
    final store = await CatalogStore.open(
      await SharedPreferences.getInstance(),
    );
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          Provider(create: (_) => FormGuard()),
        ],
        child: const LibraryApp(),
      ),
    );
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Не удалось открыть хранилище браузера. Разрешите сохранение данных и обновите страницу.\n$e',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Библиотечная система',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff6f7fb),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    ),
    routerConfig: appRouter,
  );
}
