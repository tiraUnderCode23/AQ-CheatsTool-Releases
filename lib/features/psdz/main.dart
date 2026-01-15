import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/psdz_service.dart';
import 'services/zgw_simulator_complete.dart';
import 'services/psdz_data_loader.dart';
import 'services/backup_scanner_service.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(1100, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'BMW PSDZ Ultimate Tool',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PSDZService()),
        ChangeNotifierProvider(create: (_) => ZGWSimulatorComplete()),
        ChangeNotifierProvider(create: (_) => PsdzDataLoaderService()),
        ChangeNotifierProvider(create: (_) => BackupScannerService()),
      ],
      child: const BMWPSDZUltimateApp(),
    ),
  );
}
