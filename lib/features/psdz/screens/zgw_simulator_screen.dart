// Enhanced ZGW Simulator Screen - Complete Unified Version
// Full vehicle streaming with backup loading, PSDZ matching, and real ECU simulation
//
// Developer: M A coding
// Website: https://bmw-az.info/
// Signature: AQ///bimmer

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/aq_theme.dart';
import '../services/zgw_simulator_complete.dart';
import '../services/psdz_service.dart';
import '../services/backup_scanner_service.dart';

class ZGWSimulatorScreen extends StatefulWidget {
  const ZGWSimulatorScreen({super.key});

  @override
  State<ZGWSimulatorScreen> createState() => _ZGWSimulatorScreenState();
}

class _ZGWSimulatorScreenState extends State<ZGWSimulatorScreen> {
  // NOTE: We must not share one ScrollController across multiple scroll views.
  // This screen uses an IndexedStack (keeps widgets alive), so each log view
  // gets its own controller.
  final ScrollController _simLogScrollController = ScrollController();
  final ScrollController _protocolLogScrollController = ScrollController();

  bool _autoScrollLogs = true;
  int _lastLogCount = 0;

  int _selectedTab = 0;
  int _mainTab = 0; // 0 = Simulator, 1 = Protocol, 2 = Settings

  // Search query
  String _backupSearchQuery = '';

  // Discovery settings UI
  final TextEditingController _discoveryAllowIpController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-scan on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final psdz = context.read<PSDZService>();
      if (psdz.matchedVehicles.isEmpty && !psdz.isLoading) {
        psdz.autoScanDataFolder();
      }
      // Scan backups using complete simulator
      final zgw = context.read<ZGWSimulatorComplete>();
      // Load build/version info for header display
      zgw.ensureBuildInfoLoaded();
      zgw.scanBackups();
    });
  }

  @override
  void dispose() {
    _simLogScrollController.dispose();
    _protocolLogScrollController.dispose();
    _discoveryAllowIpController.dispose();
    super.dispose();
  }

  bool _isNearBottom(ScrollController controller, {double thresholdPx = 120}) {
    if (!controller.hasClients) return true;
    final position = controller.position;
    final remaining = position.maxScrollExtent - position.pixels;
    return remaining <= thresholdPx;
  }

  void _scrollToBottom(ScrollController controller, {bool animate = true}) {
    if (!controller.hasClients) return;
    final target = controller.position.maxScrollExtent;
    if (animate) {
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else {
      controller.jumpTo(target);
    }
  }

  void _maybeAutoScroll(ZGWSimulatorComplete zgw) {
    final count = zgw.logs.length;
    if (count == _lastLogCount) return;
    _lastLogCount = count;

    if (!_autoScrollLogs) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only follow tail when user is near the bottom in that view.
      if (_isNearBottom(_simLogScrollController)) {
        _scrollToBottom(_simLogScrollController, animate: true);
      }
      if (_isNearBottom(_protocolLogScrollController)) {
        _scrollToBottom(_protocolLogScrollController, animate: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ZGWSimulatorComplete, PSDZService>(
      builder: (context, zgw, psdz, _) {
        _maybeAutoScroll(zgw);
        return ScaffoldPage(
          padding: const EdgeInsets.all(16),
          content: Column(
            children: [
              // Header with status
              _buildHeader(zgw),
              const SizedBox(height: 12),

              // Main Tab Navigation
              _buildMainTabBar(),
              const SizedBox(height: 12),

              // Main Content
              Expanded(
                child: IndexedStack(
                  index: _mainTab,
                  children: [
                    _buildSimulatorContent(zgw, psdz),
                    _buildProtocolContent(zgw),
                    _buildSettingsContent(zgw, psdz),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainTabBar() {
    final tabs = [
      ('Simulator', FluentIcons.play),
      ('Protocol Logs', FluentIcons.text_document),
      ('Settings', FluentIcons.settings),
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AQColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ToggleButton(
                checked: _mainTab == i,
                onChanged: (_) => setState(() => _mainTab = i),
                style: ToggleButtonThemeData(
                  checkedButtonStyle: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      AQColors.primaryBlue,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tabs[i].$2, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        tabs[i].$1,
                        style: TextStyle(
                          fontWeight: _mainTab == i
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          // Quick actions
          if (_mainTab == 0) ...[
            Text('DoIP: ', style: const TextStyle(fontSize: 11)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AQColors.primaryBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '13400',
                style: TextStyle(fontFamily: 'Consolas', fontSize: 10),
              ),
            ),
            const SizedBox(width: 12),
            Text('HSFZ: ', style: const TextStyle(fontSize: 11)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AQColors.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '6801/6811',
                style: TextStyle(fontFamily: 'Consolas', fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimulatorContent(ZGWSimulatorComplete zgw, PSDZService psdz) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left - Configuration & Vehicle Selection
        SizedBox(width: 420, child: _buildLeftPanel(zgw, psdz)),
        const SizedBox(width: 16),

        // Right - Logs & ECU Info
        Expanded(child: _buildRightPanel(zgw)),
      ],
    );
  }

  Widget _buildProtocolContent(ZGWSimulatorComplete zgw) {
    return GlassCard(
      title: '📜 Protocol Communication Logs',
      icon: FluentIcons.text_document,
      expand: true,
      child: Column(
        children: [
          // Filter controls
          Row(
            children: [
              const Text(
                'Filter: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (var type in ['ALL', 'DoIP', 'HSFZ', 'UDS'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ToggleButton(
                    checked: true, // Would track filter state
                    onChanged: (_) {},
                    child: Text(type, style: const TextStyle(fontSize: 11)),
                  ),
                ),
              const Spacer(),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.download, size: 14),
                    SizedBox(width: 6),
                    Text('Export Log'),
                  ],
                ),
                onPressed: () => _exportProtocolLog(zgw),
              ),
              const SizedBox(width: 8),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.clear, size: 14),
                    SizedBox(width: 6),
                    Text('Clear'),
                  ],
                ),
                onPressed: () => zgw.clearLogs(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Log viewer
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FluentTheme.of(context).cardColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Scrollbar(
                controller: _protocolLogScrollController,
                child: ListView.builder(
                  controller: _protocolLogScrollController,
                  itemCount: zgw.logs.length,
                  itemBuilder: (context, index) {
                    final logEntry = zgw.logs[index];

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              logEntry.timeString,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Consolas',
                                color: AQColors.textSecondary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _getLogTypeColor(
                                logEntry.type,
                              ).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              logEntry.type,
                              style: TextStyle(
                                fontSize: 9,
                                color: _getLogTypeColor(logEntry.type),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              logEntry.message,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'Consolas',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'DOIP':
        return AQColors.primaryBlue;
      case 'HSFZ':
        return AQColors.success;
      case 'UDS':
        return Colors.orange;
      case 'ERROR':
        return AQColors.secondaryRed;
      default:
        return AQColors.textSecondary;
    }
  }

  Widget _buildSettingsContent(ZGWSimulatorComplete zgw, PSDZService psdz) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Network settings
        Expanded(
          child: GlassCard(
            title: '🌐 Network Settings',
            icon: FluentIcons.globe,
            expand: true,
            child: ListView(
              children: [
                InfoLabel(
                  label: 'DoIP Port',
                  child: TextBox(
                    controller: TextEditingController(text: '13400'),
                    onChanged: (v) {},
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'HSFZ Port (Data)',
                  child: TextBox(
                    controller: TextEditingController(text: '6801'),
                    onChanged: (v) {},
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'HSFZ Port (Control)',
                  child: TextBox(
                    controller: TextEditingController(text: '6811'),
                    onChanged: (v) {},
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Auto-start on load: '),
                    ToggleSwitch(checked: false, onChanged: (v) {}),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Enable HSFZ Protocol: '),
                    ToggleSwitch(checked: true, onChanged: (v) {}),
                  ],
                ),

                const SizedBox(height: 18),
                const Text(
                  'Discovery (ISTA/E-Sys)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Allow discovery from public IPs (less safe, but may be required for VPN/virtual adapters)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    ToggleSwitch(
                      checked: zgw.allowDiscoveryFromPublicIps,
                      onChanged: (v) => zgw.allowDiscoveryFromPublicIps = v,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InfoLabel(
                  label: 'Discovery rate limit (ms per endpoint)',
                  child: NumberBox(
                    value: zgw.discoveryRateLimit.inMilliseconds,
                    min: 0,
                    max: 10000,
                    smallChange: 100,
                    largeChange: 500,
                    onChanged: (v) {
                      final ms = (v ?? 0).toInt();
                      zgw.discoveryRateLimit = Duration(milliseconds: ms);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                InfoLabel(
                  label: 'Discovery IP allowlist (IPv4)',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: _discoveryAllowIpController,
                          placeholder: 'e.g. 26.187.99.163',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        child: const Text('Add'),
                        onPressed: () {
                          final ip = _discoveryAllowIpController.text;
                          final ok = zgw.addDiscoveryAllowlistIp(ip);
                          if (ok) {
                            _discoveryAllowIpController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                if (zgw.discoveryIpAllowlist.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final ip in zgw.discoveryIpAllowlist)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AQColors.primaryBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AQColors.primaryBlue.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ip,
                                style: const TextStyle(
                                  fontFamily: 'Consolas',
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(FluentIcons.clear, size: 12),
                                onPressed: () =>
                                    zgw.removeDiscoveryAllowlistIp(ip),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Data paths
        Expanded(
          child: GlassCard(
            title: '📁 Data Paths',
            icon: FluentIcons.folder,
            expand: true,
            child: ListView(
              children: [
                InfoLabel(
                  label: 'PSDZ Data Path',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: TextEditingController(
                            text: zgw.psdzDataPath,
                          ),
                          onChanged: (v) => zgw.psdzDataPath = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        child: const Text('...'),
                        onPressed: () async {
                          final result = await FilePicker.platform
                              .getDirectoryPath();
                          if (result != null) zgw.psdzDataPath = result;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'Vehicle Data Path',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: TextEditingController(
                            text: psdz.autoScanPath,
                          ),
                          onChanged: (v) => psdz.autoScanPath = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        child: const Text('...'),
                        onPressed: () async {
                          final result = await FilePicker.platform
                              .getDirectoryPath();
                          if (result != null) psdz.autoScanPath = result;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoLabel(
                  label: 'Backup Path',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: TextEditingController(
                            text: zgw.backupPath,
                          ),
                          onChanged: (v) => zgw.backupPath = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        child: const Text('...'),
                        onPressed: () async {
                          final result = await FilePicker.platform
                              .getDirectoryPath();
                          if (result != null) zgw.backupPath = result;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportProtocolLog(ZGWSimulatorComplete zgw) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Protocol Log',
      fileName: 'zgw_protocol_log_${DateTime.now().millisecondsSinceEpoch}.txt',
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('ZGW Simulator Protocol Log');
      buffer.writeln('Generated by BMW PSDZ Ultimate Tool');
      buffer.writeln('=' * 60);

      for (var logString in zgw.logs) {
        buffer.writeln(logString);
      }

      await File(result).writeAsString(buffer.toString());
    }
  }

  Widget _buildHeader(ZGWSimulatorComplete zgw) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final headerTextColor = (zgw.isRunning || isDark)
        ? Colors.white
        : AQColors.lightTextPrimary;

    // Check if we can go back (opened via Navigator.push)
    final canPop = Navigator.of(context).canPop();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                FluentIcons.car,
                size: 20,
                color: isDark ? AQColors.primaryBlue : AQColors.lightHighlight,
              ),
              const SizedBox(width: 8),
              Text(
                'ZGW DoIP Simulator',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AQColors.textPrimary
                      : AQColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Status container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: zgw.isRunning ? AQColors.primaryGradient : null,
            color: zgw.isRunning ? null : FluentTheme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: zgw.isRunning
                ? [
                    BoxShadow(
                      color: AQColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: zgw.isRunning
                      ? AQColors.success
                      : AQColors.secondaryRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (zgw.isRunning
                                  ? AQColors.success
                                  : AQColors.secondaryRed)
                              .withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  zgw.isRunning ? FluentIcons.accept : FluentIcons.cancel,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 20),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          zgw.isRunning
                              ? '✓ ZGW Simulator Running'
                              : 'ZGW Simulator Stopped',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: headerTextColor,
                          ),
                        ),
                        if (zgw.connectedClients > 0) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AQColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${zgw.connectedClients} client(s)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      zgw.isRunning
                          ? 'DoIP: 0.0.0.0:13400 | HSFZ: 0.0.0.0:6801/6811'
                          : 'Click Start to begin simulation',
                      style: TextStyle(
                        fontSize: 12,
                        color: headerTextColor.withOpacity(0.8),
                      ),
                    ),
                    if (zgw.buildInfo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Build: ${zgw.buildInfo}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'Consolas',
                            color: headerTextColor.withOpacity(0.85),
                          ),
                        ),
                      ),
                    if (zgw.streamingVehicle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '🚗 ${zgw.streamingVehicle!.displayName} | VIN: ${zgw.vin}',
                          style: TextStyle(
                            fontSize: 11,
                            color: headerTextColor.withOpacity(0.9),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Control buttons
              Column(
                children: [
                  if (!zgw.isRunning)
                    FilledButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          AQColors.success,
                        ),
                      ),
                      child: const SizedBox(
                        width: 80,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.play, size: 16),
                            SizedBox(width: 8),
                            Text('Start'),
                          ],
                        ),
                      ),
                      onPressed: () => zgw.start(),
                    )
                  else
                    FilledButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          AQColors.secondaryRed,
                        ),
                      ),
                      child: const SizedBox(
                        width: 80,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.stop, size: 16),
                            SizedBox(width: 8),
                            Text('Stop'),
                          ],
                        ),
                      ),
                      onPressed: () => zgw.stop(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPanel(ZGWSimulatorComplete zgw, PSDZService psdz) {
    return Column(
      children: [
        // Tabs
        Container(
          decoration: BoxDecoration(
            color: FluentTheme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              _buildTab('Vehicle', FluentIcons.car, 0),
              _buildTab('Backup', FluentIcons.cloud_download, 1),
              _buildTab('Manual', FluentIcons.edit, 2),
              _buildTab('ECUs', FluentIcons.processing, 3),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: FluentTheme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildVehicleTab(zgw, psdz),
                _buildBackupVehicleTab(zgw, psdz),
                _buildManualTab(zgw),
                _buildECUsTab(zgw),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Tab for selecting a vehicle from backup to stream into virtual system
  Widget _buildBackupVehicleTab(ZGWSimulatorComplete zgw, PSDZService psdz) {
    final vehicles = zgw.backupVehicles.where((v) {
      if (_backupSearchQuery.isEmpty) return true;
      return v.vin.toLowerCase().contains(_backupSearchQuery.toLowerCase()) ||
          v.series.toLowerCase().contains(_backupSearchQuery.toLowerCase()) ||
          v.folderName.toLowerCase().contains(_backupSearchQuery.toLowerCase());
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header with search
        Row(
          children: [
            const Text(
              '📦 Backup Vehicles',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            Button(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (zgw.isLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  else
                    const Icon(FluentIcons.refresh, size: 12),
                  const SizedBox(width: 6),
                  const Text('Scan'),
                ],
              ),
              onPressed: zgw.isLoading
                  ? null
                  : () async {
                      await zgw.scanBackups();
                      if (mounted) setState(() {});
                    },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search box
        TextBox(
          placeholder: 'Search VIN, Series...',
          onChanged: (v) => setState(() => _backupSearchQuery = v),
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(FluentIcons.search, size: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Info bar
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AQColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AQColors.primaryBlue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                FluentIcons.info,
                size: 14,
                color: AQColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Select a vehicle from backup to stream FA/SVT data into the virtual ZGW simulator.',
                  style: TextStyle(fontSize: 11, color: AQColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Vehicle list
        if (vehicles.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AQColors.textSecondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(
                  FluentIcons.cloud_download,
                  size: 32,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                const Text('No backup vehicles found'),
                const SizedBox(height: 4),
                Text(
                  'Path: ${zgw.backupPath}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ...vehicles.map((vehicle) {
            final isStreaming = zgw.streamingVehicle?.vin == vehicle.vin;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _loadBackupVehicle(zgw, psdz, vehicle),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isStreaming
                        ? AQColors.accentCyan.withOpacity(0.2)
                        : AQColors.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isStreaming
                          ? AQColors.accentCyan
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.cloud_download,
                            size: 16,
                            color: isStreaming ? AQColors.accentCyan : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              vehicle.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isStreaming)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AQColors.accentCyan,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'STREAMING',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'VIN: ${vehicle.vin}',
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Series: ${vehicle.series} • ECUs: ${vehicle.ecus.length}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildBackupBadge('FA', vehicle.hasFA),
                          const SizedBox(width: 6),
                          _buildBackupBadge('SVT', vehicle.hasSVT),
                          const SizedBox(width: 6),
                          _buildBackupBadge('FSC', vehicle.fscCodes.isNotEmpty),
                          const Spacer(),
                          GlassButton(
                            text: isStreaming ? 'Active' : 'Stream',
                            icon: isStreaming
                                ? FluentIcons.accept
                                : FluentIcons.play,
                            color: isStreaming
                                ? AQColors.accentCyan
                                : AQColors.primaryBlue,
                            height: 32,
                            onPressed: isStreaming
                                ? null
                                : () => _loadBackupVehicle(zgw, psdz, vehicle),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildBackupBadge(String label, bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: available
            ? AQColors.success.withOpacity(0.3)
            : AQColors.secondaryRed.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: available ? AQColors.success : AQColors.secondaryRed,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: available ? AQColors.success : AQColors.secondaryRed,
        ),
      ),
    );
  }

  Future<void> _loadBackupVehicle(
    ZGWSimulatorComplete zgw,
    PSDZService psdz,
    BackupVehicle vehicle,
  ) async {
    // Load vehicle data from backup using complete simulator
    await zgw.loadBackupVehicle(vehicle);

    // Add to simulator logs
    zgw.addLog('BACKUP', 'Streaming vehicle: ${vehicle.displayName}');
    zgw.addLog('BACKUP', 'VIN: ${vehicle.vin}');
    zgw.addLog('BACKUP', 'Series: ${vehicle.series}');
    zgw.addLog('BACKUP', 'ECUs loaded: ${vehicle.ecus.length}');

    if (mounted) {
      setState(() {});
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Backup Vehicle Loaded'),
          content: Text('${vehicle.displayName} - ${vehicle.ecus.length} ECUs'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    }
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? FluentTheme.of(context).cardColor : null,
            borderRadius: BorderRadius.only(
              topLeft: index == 0 ? const Radius.circular(8) : Radius.zero,
              topRight: index == 2 ? const Radius.circular(8) : Radius.zero,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? FluentTheme.of(context).accentColor : null,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : null,
                  color: isSelected
                      ? FluentTheme.of(context).accentColor
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleTab(ZGWSimulatorComplete zgw, PSDZService psdz) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scan button
        Row(
          children: [
            const Text(
              'Available Vehicles',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(FluentIcons.folder_open, size: 14),
              onPressed: () async {
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  psdz.autoScanPath = result;
                  psdz.autoScanDataFolder();
                }
              },
            ),
            const SizedBox(width: 8),
            Button(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (psdz.isLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  else
                    const Icon(FluentIcons.refresh, size: 12),
                  const SizedBox(width: 6),
                  const Text('Scan'),
                ],
              ),
              onPressed: psdz.isLoading
                  ? null
                  : () => psdz.autoScanDataFolder(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Vehicle list
        if (psdz.matchedVehicles.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AQColors.textSecondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(FluentIcons.car, size: 32, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('No vehicles found'),
                const SizedBox(height: 4),
                Text(
                  'Add FA/SVT files to ${psdz.autoScanPath}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ...List.generate(psdz.matchedVehicles.length, (index) {
            final vehicle = psdz.matchedVehicles[index];
            final isSelected = psdz.selectedVehicle == vehicle;
            final isLoaded = zgw.streamingVehicle?.vin == vehicle.vin;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () async {
                  psdz.selectVehicle(vehicle);
                  await zgw.loadMatchedVehicle(vehicle);
                  if (mounted) {
                    await displayInfoBar(
                      context,
                      builder: (context, close) => InfoBar(
                        title: const Text('Vehicle Loaded'),
                        content: Text(vehicle.displayName),
                        severity: InfoBarSeverity.success,
                        action: IconButton(
                          icon: const Icon(FluentIcons.clear),
                          onPressed: close,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLoaded
                        ? AQColors.success.withOpacity(0.2)
                        : isSelected
                        ? FluentTheme.of(context).accentColor.withOpacity(0.1)
                        : AQColors.textSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLoaded
                          ? AQColors.success
                          : isSelected
                          ? FluentTheme.of(context).accentColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.car,
                            size: 16,
                            color: isLoaded ? AQColors.success : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              vehicle.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isLoaded)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AQColors.success,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'VIN: ${vehicle.vin}',
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 11,
                        ),
                      ),
                      if (vehicle.istep != null)
                        Text(
                          'I-Step: ${vehicle.istep}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (vehicle.faFile != null)
                            _buildFileChip('FA', Colors.green),
                          if (vehicle.svtFile != null)
                            _buildFileChip('SVT', Colors.blue),
                          if (vehicle.talFiles.isNotEmpty)
                            _buildFileChip('TAL', Colors.orange),
                          const Spacer(),
                          if (vehicle.svtFile != null)
                            Text(
                              '${vehicle.svtFile!.ecuCount} ECUs',
                              style: const TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

        // Load button
        if (psdz.selectedVehicle != null) ...[
          const SizedBox(height: 16),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AQColors.primaryBlue),
            ),
            onPressed: () async {
              await zgw.loadMatchedVehicle(psdz.selectedVehicle!);
              if (mounted) {
                await displayInfoBar(
                  context,
                  builder: (context, close) => InfoBar(
                    title: const Text('Vehicle Loaded'),
                    content: Text(psdz.selectedVehicle!.displayName),
                    severity: InfoBarSeverity.success,
                    action: IconButton(
                      icon: const Icon(FluentIcons.clear),
                      onPressed: close,
                    ),
                  ),
                );
              }
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.play, size: 14),
                SizedBox(width: 8),
                Text('Load Selected Vehicle'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildManualTab(ZGWSimulatorComplete zgw) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // VIN
        InfoLabel(
          label: 'VIN (Vehicle Identification Number)',
          child: TextBox(
            controller: TextEditingController(text: zgw.vin),
            maxLength: 17,
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 14),
            onSubmitted: (value) => zgw.setVIN(value),
          ),
        ),
        const SizedBox(height: 16),

        // I-Step
        InfoLabel(
          label: 'I-Step',
          child: TextBox(
            controller: TextEditingController(text: zgw.iStep),
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 14),
            onSubmitted: (value) => zgw.setIStep(value),
          ),
        ),
        const SizedBox(height: 16),

        // PSDZ Data Path
        InfoLabel(
          label: 'PSDZ Data Path',
          child: Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: TextEditingController(text: zgw.psdzDataPath),
                  onChanged: (value) => zgw.psdzDataPath = value,
                ),
              ),
              const SizedBox(width: 8),
              Button(
                child: const Text('Browse'),
                onPressed: () async {
                  final result = await FilePicker.platform.getDirectoryPath();
                  if (result != null) {
                    zgw.psdzDataPath = result;
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const MStripes(height: 3),
        const SizedBox(height: 24),

        // FA File
        const Text(
          'Manual File Selection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Button(
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.document, size: 14),
              SizedBox(width: 8),
              Text('Load FA File'),
            ],
          ),
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['xml'],
            );
            if (result != null && result.files.single.path != null) {
              // Manual FA loading would go here
            }
          },
        ),
        const SizedBox(height: 8),

        Button(
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.document, size: 14),
              SizedBox(width: 8),
              Text('Load SVT File'),
            ],
          ),
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['xml'],
            );
            if (result != null && result.files.single.path != null) {
              // Manual SVT loading would go here
            }
          },
        ),
      ],
    );
  }

  Widget _buildECUsTab(ZGWSimulatorComplete zgw) {
    final ecuAddresses = zgw.ecuAddresses;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Simulated ECUs (${ecuAddresses.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),

        if (ecuAddresses.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AQColors.textSecondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              children: [
                Icon(FluentIcons.processing, size: 32, color: Colors.grey),
                const SizedBox(height: 8),
                Text('No ECUs loaded'),
                const SizedBox(height: 4),
                Text(
                  'Load a vehicle to see ECUs',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ...ecuAddresses.map((address) {
            final ecu = zgw.getECU(address);
            if (ecu == null) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AQColors.textSecondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AQColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '0x${address.toRadixString(16).toUpperCase().padLeft(4, '0')}',
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ecu.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Button(
                        child: const Text(
                          'Add DTC',
                          style: TextStyle(fontSize: 10),
                        ),
                        onPressed: () =>
                            _showAddDTCDialog(context, zgw, address),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        child: const Text(
                          'Clear DTCs',
                          style: TextStyle(fontSize: 10),
                        ),
                        onPressed: () {
                          zgw.clearDTCs(address);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showAddDTCDialog(
    BuildContext context,
    ZGWSimulatorComplete zgw,
    int address,
  ) {
    final TextEditingController dtcController = TextEditingController();
    showFluentDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('Add DTC'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter DTC code (Hex, e.g., 123456):'),
              const SizedBox(height: 8),
              TextBox(controller: dtcController, placeholder: 'DTC Hex Code'),
            ],
          ),
          actions: [
            Button(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            FilledButton(
              child: const Text('Add'),
              onPressed: () {
                final text = dtcController.text.trim();
                if (text.isNotEmpty) {
                  try {
                    final dtc = int.parse(text, radix: 16);
                    zgw.addDTC(address, dtc);
                    Navigator.pop(context);
                  } catch (e) {
                    // Handle invalid input
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRightPanel(ZGWSimulatorComplete zgw) {
    return GlassCard(
      title: '📋 Communication Log',
      icon: FluentIcons.message,
      expand: true,
      child: Column(
        children: [
          // Log controls
          Row(
            children: [
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.clear, size: 14),
                    SizedBox(width: 6),
                    Text('Clear'),
                  ],
                ),
                onPressed: () => zgw.clearLogs(),
              ),
              const SizedBox(width: 8),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.copy, size: 14),
                    SizedBox(width: 6),
                    Text('Copy All'),
                  ],
                ),
                onPressed: () async {
                  final text = zgw.logs.join('\n');
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    await displayInfoBar(
                      context,
                      builder: (context, close) => InfoBar(
                        title: const Text('Copied'),
                        content: const Text('Logs copied to clipboard'),
                        severity: InfoBarSeverity.success,
                        action: IconButton(
                          icon: const Icon(FluentIcons.clear),
                          onPressed: close,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.save, size: 14),
                    SizedBox(width: 6),
                    Text('Export'),
                  ],
                ),
                onPressed: () async {
                  final result = await FilePicker.platform.saveFile(
                    dialogTitle: 'Save Logs',
                    fileName: 'zgw_logs.txt',
                    type: FileType.custom,
                    allowedExtensions: ['txt'],
                  );
                  if (result != null) {
                    try {
                      final file = File(result);
                      await file.writeAsString(zgw.logs.join('\n'));
                      if (context.mounted) {
                        await displayInfoBar(
                          context,
                          builder: (context, close) => InfoBar(
                            title: const Text('Saved'),
                            content: Text('Logs saved to $result'),
                            severity: InfoBarSeverity.success,
                            action: IconButton(
                              icon: const Icon(FluentIcons.clear),
                              onPressed: close,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        await displayInfoBar(
                          context,
                          builder: (context, close) => InfoBar(
                            title: const Text('Error'),
                            content: Text('Failed to save logs: $e'),
                            severity: InfoBarSeverity.error,
                            action: IconButton(
                              icon: const Icon(FluentIcons.clear),
                              onPressed: close,
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Auto-scroll',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  ToggleSwitch(
                    checked: _autoScrollLogs,
                    onChanged: (v) {
                      setState(() => _autoScrollLogs = v);
                      if (v) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom(
                            _simLogScrollController,
                            animate: true,
                          );
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(FluentIcons.chevron_down, size: 16),
                    onPressed: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom(_simLogScrollController, animate: true);
                      });
                    },
                  ),
                ],
              ),
              Text(
                '${zgw.logs.length} messages',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Log content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Scrollbar(
                controller: _simLogScrollController,
                child: ListView.builder(
                  controller: _simLogScrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: zgw.logs.length,
                  itemBuilder: (context, index) {
                    final log = zgw.logs[index];
                    Color color = Colors.white;
                    final logMessage = log.message;
                    final logType = log.type.toUpperCase();

                    // Color based on type
                    switch (logType) {
                      case 'DOIP':
                        color = AQColors.primaryBlue;
                        break;
                      case 'HSFZ':
                        color = AQColors.success;
                        break;
                      case 'UDS':
                        color = Colors.orange;
                        break;
                      case 'ERR':
                      case 'ERROR':
                        color = AQColors.secondaryRed;
                        break;
                      case 'FA':
                      case 'SVT':
                      case 'VEH':
                        color = AQColors.accentCyan;
                        break;
                      case 'PSDZ':
                      case 'CAFD':
                        color = AQColors.mPurple;
                        break;
                      case 'SCAN':
                      case 'SYS':
                        color = AQColors.warning;
                        break;
                      default:
                        color = Colors.white;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        '[${log.timeString}] [$logType] $logMessage',
                        style: TextStyle(
                          color: color,
                          fontFamily: 'Consolas',
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
