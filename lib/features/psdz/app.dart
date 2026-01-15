import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';

import 'theme/aq_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

class BMWPSDZUltimateApp extends StatefulWidget {
  const BMWPSDZUltimateApp({super.key});

  @override
  State<BMWPSDZUltimateApp> createState() => _BMWPSDZUltimateAppState();
}

class _BMWPSDZUltimateAppState extends State<BMWPSDZUltimateApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: FluentApp(
            title: 'AQ///PSDZ - BMW Professional Tool',
            debugShowCheckedModeBanner: false,
            theme: AQTheme.light,
            darkTheme: AQTheme.dark,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
