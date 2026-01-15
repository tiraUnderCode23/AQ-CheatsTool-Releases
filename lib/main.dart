import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'core/theme/app_theme.dart';
import 'core/providers/app_provider.dart';
import 'core/providers/activation_provider.dart';
import 'core/providers/zgw_provider.dart';
import 'core/providers/cc_messages_provider.dart';
import 'core/services/temp_files_service.dart';
import 'core/services/resource_decryptor.dart';
import 'core/services/auto_update_service.dart';
import 'core/services/http_client_service.dart';
import 'features/splash/splash_screen.dart';
import 'features/activation/activation_screen.dart';
import 'features/home/home_screen.dart';
import 'widgets/custom_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize HTTP client service for Windows SSL handling
  // This must be done early to ensure all HTTP calls work correctly
  HttpClientService();
  debugPrint('[App] HTTP client service initialized');

  // Initialize temp files service (stores in %TEMP%)
  await TempFilesService.initialize();

  // Initialize resource decryptor (extracts bin.aqx if present)
  await ResourceDecryptor.initialize();

  // Initialize auto-update service with background checking
  final updateService = AutoUpdateService();
  await updateService.initialize();
  debugPrint('[App] Auto-update service initialized with background checking');

  // Initialize custom window for Windows (frameless)
  if (Platform.isWindows) {
    await initializeCustomWindow();
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1a1a2e),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AQCheatsToolApp());
}

class AQCheatsToolApp extends StatelessWidget {
  const AQCheatsToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ActivationProvider()),
        ChangeNotifierProvider(create: (_) => ZGWProvider()),
        ChangeNotifierProvider(create: (_) => CCMessagesProvider()),
        // Use the singleton instance that was already initialized
        ChangeNotifierProvider.value(value: AutoUpdateService()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          return MaterialApp(
            title: 'AQ///bimmer Cheats Tool',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            builder: (context, child) {
              // Wrap entire app with custom title bar on Windows
              if (Platform.isWindows && child != null) {
                return CustomTitleBar(
                  title: 'AQ///bimmer Cheats Tool',
                  child: child,
                );
              }
              return child ?? const SizedBox.shrink();
            },
            home: const SplashScreen(),
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/activation': (context) => const ActivationScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
