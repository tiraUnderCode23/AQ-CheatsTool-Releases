import 'package:fluent_ui/fluent_ui.dart' hide Colors;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'theme/aq_theme.dart';
import 'providers/theme_provider.dart';
import 'services/psdz_service.dart';
import 'services/zgw_simulator_complete.dart';
import 'screens/home_screen.dart';

/// PSDZ Tab - Embeds the full BMW PSDZ Ultimate app as a tab
/// This wraps the original fluent_ui based app inside the AQ CheatsTool
class PsdzTab extends StatefulWidget {
  const PsdzTab({super.key});

  @override
  State<PsdzTab> createState() => _PsdzTabState();
}

class _PsdzTabState extends State<PsdzTab> {
  @override
  Widget build(BuildContext context) {
    // Provide PSDZ-specific services
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PSDZService()),
        ChangeNotifierProvider(create: (_) => ZGWSimulatorComplete()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Use FluentApp.router to provide all required context including localizations
          return FluentApp(
            debugShowCheckedModeBanner: false,
            theme: themeProvider.isDarkMode ? AQTheme.dark : AQTheme.light,
            localizationsDelegates: const [
              FluentLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', 'US'),
            ],
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
