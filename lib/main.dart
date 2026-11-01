import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'core/api_client.dart';
import 'repositories/catalog_store.dart';
import 'repositories/auth_api.dart';
import 'repositories/library_service.dart';
import 'state/auth_notifier.dart';
import 'state/session_policy.dart';
import 'state/form_guard.dart';
import 'widgets/inactivity_watcher.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final api = ApiClient();
  final auth = AuthNotifier(
    await SharedPreferences.getInstance(),
    AuthApi(api),
  );
  api.tokenProvider = () => auth.accessToken;
  api.refreshSession = auth.refreshTokens;
  api.expireSession = () => auth.logout(reason: SessionEnd.expired);
  await auth.restore();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => auth),
        ChangeNotifierProvider(create: (_) => CatalogStore(api)),
        Provider(create: (c) => LibraryService(c.read<CatalogStore>())),
        Provider(create: (_) => FormGuard()),
      ],
      child: LibraryApp(auth: auth),
    ),
  );
}

class LibraryApp extends StatefulWidget {
  final AuthNotifier auth;
  const LibraryApp({super.key, required this.auth});
  @override
  State<LibraryApp> createState() => _LibraryAppState();
}

class _LibraryAppState extends State<LibraryApp> {
  late final GoRouter _router;
  late String _identity;
  String get identity => '${widget.auth.user?.id}:${widget.auth.uiRole.name}';
  @override
  void initState() {
    super.initState();
    _identity = identity;
    _router = buildRouter(widget.auth);
    widget.auth.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_identity == identity) return;
    _identity = identity;
    context.read<CatalogStore>().reset();
    context.read<FormGuard>().dirty = false;
  }

  @override
  void dispose() {
    widget.auth.removeListener(_sessionChanged);
    _router.dispose();
    super.dispose();
  }

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
    routerConfig: _router,
    builder: (context, child) =>
        InactivityWatcher(child: child ?? const SizedBox.shrink()),
  );
}
