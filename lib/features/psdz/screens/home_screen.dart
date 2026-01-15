import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/aq_theme.dart';
import '../providers/theme_provider.dart';
import '../services/psdz_service.dart';
import 'psdz_analyzer_screen.dart';
import 'tal_editor_screen.dart';
import 'data_import_screen.dart';
import 'settings_screen.dart';
import 'zgw_simulator_screen.dart';

/// Main Home Screen with Windows-style layout (E-Sys Ultra inspired)
/// Features:
/// - Always open sidebar (left-to-right layout)
/// - Compact spacing for maximum screen utilization
/// - Merged screens for streamlined workflow
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Navigation items - All features enabled
  final List<_NavItem> _navItems = [
    _NavItem(
      title: 'PSDZ Analyzer',
      icon: FluentIcons.database,
      description: 'Browse Series, I-Steps & ECU Data',
    ),
    _NavItem(
      title: 'SVT-TAL Editor',
      icon: FluentIcons.edit,
      description: 'Unified SVT/TAL & Library Manager',
    ),
    _NavItem(
      title: 'ZGW Simulator',
      icon: FluentIcons.streaming,
      description: 'DoIP/HSFZ Vehicle Simulation',
    ),
    _NavItem(
      title: 'Data Manager',
      icon: FluentIcons.sync,
      description: 'Import, Export & Backup',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Auto-scan PSDZ data on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PSDZService>().scanPSDZData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive breakpoints
        final isNarrow = constraints.maxWidth < 600;
        final isCompact = constraints.maxWidth < 900;

        // Determine navigation display mode based on width
        final displayMode = isNarrow
            ? PaneDisplayMode.minimal
            : isCompact
                ? PaneDisplayMode.compact
                : PaneDisplayMode.open;

        // Responsive sidebar width
        final sidebarWidth = isNarrow ? 50.0 : (isCompact ? 50.0 : 220.0);

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark ? AQColors.backgroundGlow : null,
              color: isDark ? null : AQColors.lightBackground,
            ),
            child: Stack(
              children: [
                // Grid pattern background (dark mode only)
                if (isDark)
                  Positioned.fill(
                    child: CustomPaint(painter: GridPatternPainter()),
                  ),
                // Main navigation
                NavigationView(
                  appBar: NavigationAppBar(
                    height: isCompact ? 36 : 40,
                    automaticallyImplyLeading: false,
                    leading: _buildTitleBar(isDark, isCompact: isCompact),
                    actions: _buildAppBarActions(context, isDark,
                        isCompact: isCompact),
                  ),
                  pane: NavigationPane(
                    selected: _selectedIndex,
                    onChanged: (index) =>
                        setState(() => _selectedIndex = index),
                    displayMode: displayMode,
                    size: NavigationPaneSize(
                      openWidth: sidebarWidth,
                      openMinWidth: 50,
                      openMaxWidth: 260,
                      compactWidth: 50,
                    ),
                    header: isNarrow ? null : _buildSidebarHeader(isDark),
                    items: _buildNavItems(isDark),
                    footerItems: [
                      PaneItemSeparator(),
                      PaneItem(
                        icon: const Icon(FluentIcons.settings),
                        title: const Text('Settings'),
                        body: const SettingsScreen(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleBar(bool isDark, {bool isCompact = false}) {
    return Row(
      children: [
        SizedBox(width: isCompact ? 4 : 8),
        // AQ Logo
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 8,
            vertical: isCompact ? 2 : 4,
          ),
          decoration: BoxDecoration(
            gradient: AQColors.primaryGradient,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AQ',
                style: TextStyle(
                  color: AQColors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isCompact ? 10 : 12,
                ),
              ),
              Text(
                '///',
                style: TextStyle(
                  color: AQColors.accentCyan,
                  fontWeight: FontWeight.w900,
                  fontSize: isCompact ? 10 : 12,
                ),
              ),
              Text(
                'PSDZ',
                style: TextStyle(
                  color: AQColors.secondaryRed,
                  fontWeight: FontWeight.w900,
                  fontSize: isCompact ? 10 : 12,
                ),
              ),
            ],
          ),
        ),
        if (!isCompact) ...[
          const SizedBox(width: 12),
          Text(
            'BMW Professional Tool',
            style: TextStyle(
              color:
                  isDark ? AQColors.textSecondary : AQColors.lightTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAppBarActions(BuildContext context, bool isDark,
      {bool isCompact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Theme toggle
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            return Tooltip(
              message: themeProvider.isDarkMode
                  ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode',
              child: IconButton(
                icon: Icon(
                  themeProvider.isDarkMode
                      ? FluentIcons.sunny
                      : FluentIcons.clear_night,
                  size: isCompact ? 14 : 16,
                  color: isDark
                      ? AQColors.textSecondary
                      : AQColors.lightTextSecondary,
                ),
                onPressed: themeProvider.toggleTheme,
              ),
            );
          },
        ),
        SizedBox(width: isCompact ? 2 : 4),
        // Website
        Tooltip(
          message: 'bmw-az.info',
          child: IconButton(
            icon: Icon(
              FluentIcons.globe,
              size: isCompact ? 14 : 16,
              color:
                  isDark ? AQColors.textSecondary : AQColors.lightTextSecondary,
            ),
            onPressed: () => _launchUrl('https://bmw-az.info/'),
          ),
        ),
        SizedBox(width: isCompact ? 4 : 8),
        // Window controls
        _WindowButtons(),
      ],
    );
  }

  Widget _buildSidebarHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // M Stripes
          const MStripes(height: 3),
          const SizedBox(height: 12),
          // Status indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AQColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AQColors.success.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ready',
                style: TextStyle(
                  color: AQColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'v1.0.0',
                style: TextStyle(
                  color: isDark ? AQColors.textMuted : AQColors.lightTextMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<NavigationPaneItem> _buildNavItems(bool isDark) {
    return [
      for (var i = 0; i < _navItems.length; i++)
        PaneItem(
          icon: Icon(_navItems[i].icon),
          title: Text(_navItems[i].title),
          infoBadge: i == 0 ? _buildInfoBadge() : null,
          body: _getScreen(i),
        ),
    ];
  }

  Widget _buildInfoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AQColors.primaryBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: AQColors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const PSDZAnalyzerScreen();
      case 1:
        return const TALEditorScreen();
      case 2:
        return const ZGWSimulatorScreen();
      case 3:
        return const DataImportScreen();
      default:
        return const PSDZAnalyzerScreen();
    }
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showAboutDialog(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    showFluentDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AQColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'AQ',
                style: TextStyle(
                  color: AQColors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('BMW PSDZ Ultimate'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MStripes(height: 4),
            const SizedBox(height: 16),
            _buildAboutRow('Developer', 'M A coding', AQColors.primaryBlue),
            _buildAboutRow('Website', 'bmw-az.info', AQColors.accentCyan),
            _buildAboutRow('Signature', 'AQ///bimmer', AQColors.secondaryRed),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AQColors.cardBackground
                    : AQColors.lightSurfaceBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Professional BMW ECU Management Tool\nPSDZ Data Analyzer • TAL/SVT Editor • Data Manager',
                style: TextStyle(
                  color: isDark
                      ? AQColors.textSecondary
                      : AQColors.lightTextSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation item model
class _NavItem {
  final String title;
  final IconData icon;
  final String description;

  _NavItem({
    required this.title,
    required this.icon,
    required this.description,
  });
}

/// Window control buttons - Disabled when embedded in another app
class _WindowButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Window controls disabled when embedded as a tab
    return const SizedBox.shrink();
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.color,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.hoverColor ?? widget.color).withOpacity(0.2)
                : Colors.transparent,
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 10,
              color: _isHovered
                  ? (widget.hoverColor ?? widget.color)
                  : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
