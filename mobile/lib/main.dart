import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/api.dart';
import 'core/tokens.dart';
import 'router.dart';
import 'state/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TherapyPalApp());
}

class TherapyPalApp extends StatefulWidget {
  const TherapyPalApp({super.key});

  @override
  State<TherapyPalApp> createState() => _TherapyPalAppState();
}

class _TherapyPalAppState extends State<TherapyPalApp> {
  late final Api _api = Api();
  late final Session _session = Session(_api);
  late final Badges _badges = Badges(_api);
  late final _router = buildRouter(_session);

  @override
  void initState() {
    super.initState();
    _session.restore();
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: TP.primary, primary: TP.primary, surface: TP.surface, error: TP.danger),
      scaffoldBackgroundColor: TP.ground,
      splashFactory: InkRipple.splashFactory,
    );
    final theme = base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: TP.ink, displayColor: TP.ink),
      dividerColor: TP.line,
      textSelectionTheme: const TextSelectionThemeData(cursorColor: TP.primary),
    );
    return MultiProvider(
      providers: [
        Provider<Api>.value(value: _api),
        ChangeNotifierProvider<Session>.value(value: _session),
        ChangeNotifierProvider<Badges>.value(value: _badges),
      ],
      child: MaterialApp.router(
        title: 'Therapy Pal',
        debugShowCheckedModeBanner: true,
        theme: theme,
        routerConfig: _router,
      ),
    );
  }
}
