import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/aq_theme.dart';
import '../services/psdz_service.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _psdzPathController;
  late TextEditingController _talPathController;
  late TextEditingController _svtPathController;
  bool _autoLoadOnStart = true;

  @override
  void initState() {
    super.initState();
    _psdzPathController = TextEditingController(text: r'C:\Data\psdzdata\');
    _talPathController = TextEditingController(text: r'C:\Data\TAL\');
    _svtPathController = TextEditingController(text: r'C:\Data\SVT\');
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _psdzPathController.text =
          prefs.getString('psdz_path') ?? r'C:\Data\psdzdata\';
      _talPathController.text = prefs.getString('tal_path') ?? r'C:\Data\TAL\';
      _svtPathController.text = prefs.getString('svt_path') ?? r'C:\Data\SVT\';
      _autoLoadOnStart = prefs.getBool('auto_load') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('psdz_path', _psdzPathController.text);
    await prefs.setString('tal_path', _talPathController.text);
    await prefs.setString('svt_path', _svtPathController.text);
    await prefs.setBool('auto_load', _autoLoadOnStart);

    // Update service paths
    final psdz = Provider.of<PSDZService>(context, listen: false);
    psdz.psdzPath = _psdzPathController.text;
    await psdz.scanPSDZData();

    if (mounted) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Settings Saved'),
          content: const Text('All settings have been saved successfully.'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return ScaffoldPage(
      padding: const EdgeInsets.all(16),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back Button Header
            _buildBackHeader(isDark),
            const SizedBox(height: 12),
            // Branding Header
            _buildBrandingHeader(),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  child: Column(
                    children: [
                      // Paths Configuration
                      _buildPathsCard(),
                      const SizedBox(height: 16),

                      // Preferences
                      _buildPreferencesCard(),
                      const SizedBox(height: 16),

                      // Appearance
                      GlassCard(
                        title: '🎨 Appearance',
                        icon: FluentIcons.color,
                        child: Column(
                          children: [
                            Consumer<ThemeProvider>(
                              builder: (context, theme, _) => ToggleSwitch(
                                checked: theme.themeMode == ThemeMode.dark,
                                content: Text(
                                  theme.themeMode == ThemeMode.dark
                                      ? 'Dark Mode'
                                      : 'Light Mode',
                                ),
                                onChanged: (v) => theme.toggleTheme(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InfoLabel(
                              label: 'Transparency Effects',
                              child: ToggleSwitch(
                                checked: true,
                                content: const Text(
                                  'Enable Mica/Acrylic effects',
                                ),
                                onChanged: null, // Always on for now
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Right Column
                Expanded(
                  child: Column(
                    children: [
                      // System Info
                      _buildSystemInfoCard(),
                      const SizedBox(height: 16),

                      // Credits
                      _buildCreditsCard(),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Save Button
            Center(
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    AQColors.primaryBlue,
                  ),
                ),
                onPressed: _saveSettings,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.save, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Save Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackHeader(bool isDark) {
    // Check if we can go back (opened via Navigator.push)
    final canPop = Navigator.of(context).canPop();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AQColors.cardBackground
            : AQColors.lightSurfaceBackground,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AQColors.primaryBlue.withOpacity(0.3)
                : AQColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            IconButton(
              icon: Icon(
                FluentIcons.back,
                size: 16,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            FluentIcons.settings,
            size: 20,
            color: isDark ? AQColors.primaryBlue : AQColors.lightHighlight,
          ),
          const SizedBox(width: 8),
          Text(
            'Settings & Configuration',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AQColors.textPrimary : AQColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AQColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AQColors.primaryBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
              ],
            ),
            child: const Center(
              child: Text(
                'AQ',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AQColors.primaryBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'BMW PSDZ Ultimate',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AQColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'v1.0.0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const MStripes(height: 4),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildBrandingBadge('M A coding', AQColors.mBlue),
                    const SizedBox(width: 8),
                    _buildBrandingBadge('AQ///bimmer', AQColors.mRed),
                  ],
                ),
              ],
            ),
          ),

          // Website link
          Column(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    FluentIcons.globe,
                    color: AQColors.primaryBlue,
                    size: 24,
                  ),
                ),
                onPressed: () => _launchUrl('https://bmw-az.info/'),
              ),
              const SizedBox(height: 4),
              const Text(
                'bmw-az.info',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPathsCard() {
    return GlassCard(
      title: '📁 Data Paths',
      icon: FluentIcons.folder,
      child: Column(
        children: [
          InfoLabel(
            label: 'PSDZ Data Path',
            child: TextBox(
              controller: _psdzPathController,
              suffix: IconButton(
                icon: const Icon(FluentIcons.folder_open, size: 16),
                onPressed: () => _selectFolder(_psdzPathController),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'TAL Files Path',
            child: TextBox(
              controller: _talPathController,
              suffix: IconButton(
                icon: const Icon(FluentIcons.folder_open, size: 16),
                onPressed: () => _selectFolder(_talPathController),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'SVT Files Path',
            child: TextBox(
              controller: _svtPathController,
              suffix: IconButton(
                icon: const Icon(FluentIcons.folder_open, size: 16),
                onPressed: () => _selectFolder(_svtPathController),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Button(
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.sync, size: 14),
                SizedBox(width: 8),
                Text('Rescan All Paths'),
              ],
            ),
            onPressed: () async {
              final psdz = Provider.of<PSDZService>(context, listen: false);
              psdz.psdzPath = _psdzPathController.text;
              await psdz.scanPSDZData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return GlassCard(
      title: '⚙️ Preferences',
      icon: FluentIcons.settings,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Auto-load data on startup'),
              ToggleSwitch(
                checked: _autoLoadOnStart,
                onChanged: (value) => setState(() => _autoLoadOnStart = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Theme Toggle - Connected to ThemeProvider
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        themeProvider.isDarkMode
                            ? FluentIcons.clear_night
                            : FluentIcons.sunny,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text('Dark Mode'),
                    ],
                  ),
                  ToggleSwitch(
                    checked: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard() {
    return Consumer<PSDZService>(
      builder: (context, psdz, _) {
        return GlassCard(
          title: '📊 System Information',
          icon: FluentIcons.info,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Platform', Platform.operatingSystem.toUpperCase()),
              _buildInfoRow('PSDZ Data Size', psdz.psdzSize),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: MStripes(height: 2),
              ),
              _buildInfoRow('Series Loaded', '${psdz.seriesList.length}'),
              _buildInfoRow('Total ECUs', '${psdz.ecuCount}'),
              _buildInfoRow('Files Indexed', '${psdz.fileCount}'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: MStripes(height: 2),
              ),
              _buildInfoRow(
                'PSDZ Path Valid',
                psdz.isPathValid ? '✅ Yes' : '❌ No',
              ),
              _buildInfoRow('Last Scan', psdz.lastScanTime ?? 'Never'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreditsCard() {
    return GlassCard(
      title: '👨‍💻 Credits',
      icon: FluentIcons.people,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Developed by:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AQColors.mStripesGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'M A coding',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('AQ///bimmer', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _launchUrl('https://bmw-az.info/'),
            child: Row(
              children: [
                const Icon(FluentIcons.globe, size: 16),
                const SizedBox(width: 8),
                Text(
                  'https://bmw-az.info/',
                  style: TextStyle(
                    color: AQColors.accentCyan,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _launchUrl('https://aqbimmer.com/'),
            child: Row(
              children: [
                const Icon(FluentIcons.globe, size: 16),
                const SizedBox(width: 8),
                Text(
                  'https://aqbimmer.com/',
                  style: TextStyle(
                    color: AQColors.accentCyan,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Special thanks to the BMW coding community.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFolder(TextEditingController controller) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Folder',
    );
    if (result != null) {
      setState(() {
        controller.text = result;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    _psdzPathController.dispose();
    _talPathController.dispose();
    _svtPathController.dispose();
    super.dispose();
  }
}
