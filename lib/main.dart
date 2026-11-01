import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
import 'repositories/catalog_store.dart';
import 'state/form_guard.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogStore(ApiClient())),
        Provider(create: (_) => FormGuard()),
      ],
      child: const LibraryApp(),
    ),
  );
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
