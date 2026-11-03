import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'router.dart';
import 'services/session.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  Intl.defaultLocale = 'fr';
  final session = Session(await SharedPreferences.getInstance());
  runApp(MaillerApp(session: session));
}

class MaillerApp extends StatefulWidget {
  const MaillerApp({super.key, required this.session});

  final Session session;

  @override
  State<MaillerApp> createState() => _MaillerAppState();
}

class _MaillerAppState extends State<MaillerApp> {
  late final GoRouter _router = buildRouter(widget.session);
  final _light = buildTheme(Brightness.light);
  final _dark = buildTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: widget.session),
      ChangeNotifierProvider(create: (_) => ServerStatus(widget.session)),
    ],
    child: Consumer<Session>(
      builder: (context, session, _) => MaterialApp.router(
        title: 'Mailler Studio',
        debugShowCheckedModeBanner: false,
        theme: _light,
        darkTheme: _dark,
        themeMode: session.themeMode,
        themeAnimationDuration: const Duration(milliseconds: 350),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
      ),
    ),
  );
}
