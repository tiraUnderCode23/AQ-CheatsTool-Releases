import 'dart:io';
import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../theme/aq_theme.dart';
import '../services/psdz_service.dart';
import '../services/backup_scanner_service.dart';
import '../models/ecu.dart';
import '../models/tal_file.dart';
import '../widgets/progress_dialog.dart';
import 'tal_editor_screen.dart';

class PSDZAnalyzerScreen extends StatefulWidget {
  const PSDZAnalyzerScreen({super.key});

  @override
  State<PSDZAnalyzerScreen> createState() => _PSDZAnalyzerScreenState();
}

class _PSDZAnalyzerScreenState extends State<PSDZAnalyzerScreen> {
  String _fileTypeFilter = 'ALL';
  String _ecuSearchQuery = '';
  int _currentTab = 0;
  bool _preserveStructure = true;
  String _libraryFilter = '';
  String _librarySeriesFilter = '';
  String _vinSearchQuery = '';
  String _seriesSearchQuery = '';

  // Combined TAL/SVT + Library tab
  int _importLibraryTab = 0;

  // Backup scanner integration
  final BackupScannerService _backupScanner = BackupScannerService();
  BackupVehicle? _selectedBackupVehicle;
  String _backupSearchQuery = '';
  String _backupSeriesFilter = 'ALL';

  // Export options
  String _exportMode = 'ecu'; // 'ecu', 'series', 'istep', 'all'
  String? _selectedExportSeries;
  String? _selectedExportIStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final psdz = context.read<PSDZService>();
      psdz.scanPSDZData();
      psdz.detectPsdzVersion(); // Detect version from SDP *.ver
      psdz.autoScanDataFolder();
      psdz.scanLibrary(); // Auto-scan library for TAL/SVT files
      // Scan backup folder
      _scanBackupFolder();
    });
  }

  Future<void> _scanBackupFolder() async {
    await _backupScanner.scanBackupFolder();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PSDZService>(
      builder: (context, psdz, _) {
        final safeTab = _currentTab.clamp(0, 3);
        return ScaffoldPage(
          padding: const EdgeInsets.all(16),
          content: Column(
            children: [
              // Tab Navigation
              _buildTabBar(),
              const SizedBox(height: 16),

              // Tab Content
              Expanded(
                child: IndexedStack(
                  index: safeTab,
                  children: [
                    // Tab 0: PSDZ Analyzer
                    _buildPSDZAnalyzerTab(psdz),
                    // Tab 1: TAL/SVT + Library (merged)
                    _buildImportLibraryTab(psdz),
                    // Tab 2: Auto-Scan (VIN Match)
                    _buildAutoScanTab(psdz),
                    // Tab 3: Backup Browser
                    _buildBackupBrowserTab(psdz),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    final tabLabels = [
      'PSDZ Analyzer',
      'TAL/SVT + Library',
      'Auto-Scan',
      'Backup Browser',
    ];
    final tabLabelsCompact = [
      'Analyzer',
      'TAL/SVT',
      'Scan',
      'Backup',
    ];
    final tabIcons = [
      FluentIcons.database,
      FluentIcons.library,
      FluentIcons.car,
      FluentIcons.hard_drive,
    ];

    final safeTab = _currentTab.clamp(0, tabLabels.length - 1);
    if (safeTab != _currentTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentTab = safeTab);
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        final isVeryCompact = constraints.maxWidth < 500;
        final displayLabels = isCompact ? tabLabelsCompact : tabLabels;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 4 : 6,
            vertical: isCompact ? 2 : 4,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AQColors.surfaceBackground
                : AQColors.lightSurfaceBackground,
            borderRadius: BorderRadius.circular(isDark ? 6 : 2),
            border: Border.all(
              color: isDark
                  ? AQColors.primaryBlue.withOpacity(0.2)
                  : AQColors.lightBorder,
              width: isDark ? 1 : 1.5,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.white,
                      offset: const Offset(-1, -1),
                      blurRadius: 0,
                    ),
                    BoxShadow(
                      color: const Color(0xFF808080),
                      offset: const Offset(1, 1),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Tab buttons - flexible to avoid overflow
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < displayLabels.length; i++)
                        Padding(
                          padding: EdgeInsets.only(right: isCompact ? 2 : 3),
                          child: _buildTabButton(
                            label: isVeryCompact ? '' : displayLabels[i],
                            icon: tabIcons[i],
                            isSelected: safeTab == i,
                            onTap: () => setState(() => _currentTab = i),
                            isDark: isDark,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isVeryCompact) ...[
                // Export dropdown
                _buildExportDropdown(),
                SizedBox(width: isCompact ? 4 : 6),
              ],
              // Preserve structure toggle
              if (!isVeryCompact)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 6 : 8,
                    vertical: isCompact ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AQColors.cardBackground
                        : AQColors.lightCardBackground,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark
                          ? AQColors.textMuted.withOpacity(0.3)
                          : AQColors.lightTextMuted.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.folder_horizontal,
                        size: 12,
                        color: isDark
                            ? AQColors.textSecondary
                            : AQColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Structure:',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AQColors.textSecondary
                              : AQColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 20,
                        child: ToggleSwitch(
                          checked: _preserveStructure,
                          onChanged: (v) =>
                              setState(() => _preserveStructure = v),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: isSelected && isDark ? AQColors.primaryGradient : null,
          color: isSelected
              ? (isDark ? null : AQColors.lightHighlight)
              : (isDark
                  ? AQColors.cardBackground.withOpacity(0.5)
                  : AQColors.lightButtonFace),
          borderRadius: BorderRadius.circular(isDark ? 4 : 2),
          border: Border.all(
            color: isSelected
                ? (isDark ? AQColors.primaryBlue : AQColors.lightHighlight)
                : AQColors.lightBorder,
            width: isDark ? 0 : 1,
          ),
          boxShadow: isDark
              ? (isSelected
                  ? [
                      BoxShadow(
                        color: AQColors.primaryBlue.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null)
              : [
                  // Classic Windows 3D button effect
                  BoxShadow(
                    color: isSelected ? const Color(0xFF808080) : Colors.white,
                    offset: const Offset(-1, -1),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: isSelected ? Colors.white : const Color(0xFF808080),
                    offset: const Offset(1, 1),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? AQColors.textSecondary
                      : AQColors.lightTextPrimary),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AQColors.textSecondary
                        : AQColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportDropdown() {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        gradient: AQColors.accentGradient,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: AQColors.accentCyan.withOpacity(0.3), blurRadius: 8),
        ],
      ),
      child: DropDownButton(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.download,
              size: 12,
              color: AQColors.darkBackground,
            ),
            SizedBox(width: 6),
            Text(
              'Export',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AQColors.darkBackground,
              ),
            ),
          ],
        ),
        items: [
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.processing, size: 14),
            text: const Text('Export Selected ECU'),
            onPressed: () => _exportSelectedECU(context),
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.car, size: 14),
            text: const Text('Export by Series'),
            onPressed: () => _showExportBySeriesDialog(context),
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.timeline, size: 14),
            text: const Text('Export by I-Step'),
            onPressed: () => _showExportByIStepDialog(context),
          ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.download, size: 14),
            text: const Text('Export All Found Files'),
            onPressed: () => _exportAllFiles(context),
          ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.paste, size: 14),
            text: const Text('Export ECU List (TXT)'),
            onPressed: () => _exportEcuListTxt(context),
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.table, size: 14),
            text: const Text('Export ECU List (CSV)'),
            onPressed: () => _exportEcuListCsv(context),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSelectedECU(BuildContext context) async {
    final psdz = context.read<PSDZService>();
    if (psdz.selectedECU == null) {
      _showInfoBar(
        context,
        'Please select an ECU first',
        InfoBarSeverity.warning,
      );
      return;
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Output Folder for ${psdz.selectedECU}',
    );

    if (result != null && context.mounted) {
      final filesToExtract =
          psdz.files.where((f) => f.status == FileStatus.found).toList();

      if (filesToExtract.isEmpty) {
        _showInfoBar(
          context,
          'No found files for ${psdz.selectedECU}',
          InfoBarSeverity.warning,
        );
        return;
      }
      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(
          title: 'Extracting ${psdz.selectedECU}',
          future: _preserveStructure
              ? psdz.extractFilesWithStructure(
                  filesToExtract,
                  '$result/${psdz.selectedECU}',
                )
              : psdz.extractFiles(
                  filesToExtract,
                  '$result/${psdz.selectedECU}',
                ),
        ),
      );
    }
  }

  Future<void> _showExportBySeriesDialog(BuildContext context) async {
    final psdz = context.read<PSDZService>();

    await showFluentDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Export by Series'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select series to export:'),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: ComboBox<String>(
                value: _selectedExportSeries,
                isExpanded: true,
                placeholder: const Text('Choose series...'),
                items: psdz.series
                    .map(
                      (s) => ComboBoxItem(
                        value: s.code,
                        child: Text('${s.code} (${s.description})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedExportSeries = v),
              ),
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            child: const Text('Export'),
            onPressed: _selectedExportSeries == null
                ? null
                : () async {
                    Navigator.pop(ctx);
                    await _exportBySeries(context, _selectedExportSeries!);
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _exportBySeries(BuildContext context, String series) async {
    final psdz = context.read<PSDZService>();

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Output Folder for $series',
    );

    if (result != null && context.mounted) {
      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(
          title: 'Extracting $series files',
          future: psdz.exportBySeries(
            series,
            '$result/$series',
            preserveStructure: _preserveStructure,
          ),
        ),
      );
    }
  }

  Future<void> _showExportByIStepDialog(BuildContext context) async {
    final psdz = context.read<PSDZService>();

    await showFluentDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Export by I-Step'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select I-Step to export:'),
            const SizedBox(height: 12),
            SizedBox(
              width: 300,
              child: ComboBox<String>(
                value: _selectedExportIStep,
                isExpanded: true,
                placeholder: const Text('Choose I-Step...'),
                items: psdz.iSteps
                    .map(
                      (i) => ComboBoxItem(value: i.name, child: Text(i.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedExportIStep = v),
              ),
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            child: const Text('Export'),
            onPressed: _selectedExportIStep == null
                ? null
                : () async {
                    Navigator.pop(ctx);
                    await _exportByIStep(context, _selectedExportIStep!);
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _exportByIStep(BuildContext context, String iStep) async {
    final psdz = context.read<PSDZService>();

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Output Folder for $iStep',
    );

    if (result != null && context.mounted) {
      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(
          title: 'Extracting $iStep files',
          future: psdz.exportByIStep(
            iStep,
            '$result/$iStep',
            preserveStructure: _preserveStructure,
          ),
        ),
      );
    }
  }

  Future<void> _exportAllFiles(BuildContext context) async {
    final psdz = context.read<PSDZService>();

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Output Folder',
    );

    if (result != null && context.mounted) {
      final filesToExtract = await psdz.collectFoundFilesForCurrentIStep();
      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(
          title: 'Extracting All Files',
          future: _preserveStructure
              ? psdz.extractFilesWithStructure(filesToExtract, result)
              : psdz.extractFiles(filesToExtract, result),
        ),
      );
    }
  }

  Widget _buildImportLibraryTab(PSDZService psdz) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    final subLabels = ['TAL / SVT Import', 'Library Scanner'];
    final subIcons = [FluentIcons.download, FluentIcons.library];

    final safeSubTab = _importLibraryTab.clamp(0, subLabels.length - 1);
    if (safeSubTab != _importLibraryTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _importLibraryTab = safeSubTab);
      });
    }

    return Column(
      children: [
        // Sub-tab navigation (keeps us independent from Fluent UI tab widgets)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? AQColors.surfaceBackground
                : AQColors.lightSurfaceBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark
                  ? AQColors.primaryBlue.withOpacity(0.2)
                  : AQColors.primaryBlue.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < subLabels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildTabButton(
                    label: subLabels[i],
                    icon: subIcons[i],
                    isSelected: safeSubTab == i,
                    onTap: () => setState(() => _importLibraryTab = i),
                    isDark: isDark,
                  ),
                ),
              const Spacer(),
              Text(
                'Merged view',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AQColors.textMuted : AQColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: IndexedStack(
            index: safeSubTab,
            children: [_buildTALImportTab(psdz), _buildLibraryScanTab(psdz)],
          ),
        ),
      ],
    );
  }

  Future<void> _exportEcuListTxt(BuildContext context) async {
    final psdz = context.read<PSDZService>();

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ECU List',
      fileName:
          'ecu_list_${psdz.selectedSeries ?? "all"}_${psdz.selectedIStep ?? "all"}.txt',
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('BMW PSDZ ECU List Export');
      buffer.writeln('Generated by BMW PSDZ Ultimate Tool');
      buffer.writeln('Developer: M A coding | Website: https://bmw-az.info/');
      buffer.writeln('=' * 60);
      buffer.writeln('Series: ${psdz.selectedSeries ?? "N/A"}');
      buffer.writeln('I-Step: ${psdz.selectedIStep ?? "N/A"}');
      buffer.writeln('Total ECUs: ${psdz.ecus.length}');
      buffer.writeln('=' * 60);
      buffer.writeln();

      for (var ecu in psdz.ecus) {
        buffer.writeln('${ecu.name} (${ecu.addressHex})');
        for (var f in ecu.files) {
          final status = f.status == FileStatus.found ? '✓' : '✗';
          buffer.writeln('  $status ${f.processClass}:${f.id} ${f.version}');
        }
        buffer.writeln();
      }

      await File(result).writeAsString(buffer.toString());
      if (context.mounted) {
        _showInfoBar(
          context,
          'ECU list exported to $result',
          InfoBarSeverity.success,
        );
      }
    }
  }

  Future<void> _exportEcuListCsv(BuildContext context) async {
    final psdz = context.read<PSDZService>();

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ECU List (CSV)',
      fileName:
          'ecu_list_${psdz.selectedSeries ?? "all"}_${psdz.selectedIStep ?? "all"}.csv',
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('ECU,Address,FileType,FileID,Version,Status,Path');

      for (var ecu in psdz.ecus) {
        for (var f in ecu.files) {
          final status = f.status == FileStatus.found ? 'Found' : 'Missing';
          buffer.writeln(
            '${ecu.name},${ecu.addressHex},${f.processClass},${f.id},${f.version},$status,${f.path ?? ""}',
          );
        }
      }

      await File(result).writeAsString(buffer.toString());
      if (context.mounted) {
        _showInfoBar(
          context,
          'CSV exported to $result',
          InfoBarSeverity.success,
        );
      }
    }
  }

  void _showInfoBar(
    BuildContext context,
    String message,
    InfoBarSeverity severity,
  ) {
    displayInfoBar(
      context,
      builder: (ctx, close) {
        return InfoBar(
          title: Text(message),
          severity: severity,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      },
    );
  }

  Future<void> _revealInExplorer(String path) async {
    try {
      final normalized = path.replaceAll('/', '\\');
      await Process.start('explorer.exe', ['/select,', normalized]);
    } catch (e) {
      if (mounted) {
        _showInfoBar(
          context,
          'Failed to open Explorer: $e',
          InfoBarSeverity.error,
        );
      }
    }
  }

  Future<void> _openInTalEditor(PSDZService psdz, String path) async {
    try {
      await psdz.loadTALFile(path);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(FluentPageRoute(builder: (_) => const TALEditorScreen()));
    } catch (e) {
      if (mounted) {
        _showInfoBar(
          context,
          'Failed to open editor: $e',
          InfoBarSeverity.error,
        );
      }
    }
  }

  Future<void> _extractCurrentTal(
    PSDZService psdz, {
    required bool preserveStructure,
    String? defaultSubfolder,
    String title = 'Extracting ECUs',
  }) async {
    if (psdz.currentTALFile == null) {
      _showInfoBar(context, 'No TAL/SVT file loaded', InfoBarSeverity.warning);
      return;
    }

    try {
      final out = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Output Folder',
      );
      if (out == null || !mounted) return;

      final target =
          defaultSubfolder == null ? out : p.join(out, defaultSubfolder);

      final future = psdz.extractTALECUs(
        target,
        preserveStructure: preserveStructure,
      );

      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(title: title, future: future),
      );

      final extracted = await future;
      if (mounted) {
        _showInfoBar(
          context,
          extracted > 0
              ? 'Extracted $extracted files to $target'
              : 'No files extracted (nothing found in PSDZDATA)',
          extracted > 0 ? InfoBarSeverity.success : InfoBarSeverity.warning,
        );
      }
    } catch (e) {
      if (mounted) {
        _showInfoBar(context, 'Extraction error: $e', InfoBarSeverity.error);
      }
    }
  }

  Widget _buildPSDZAnalyzerTab(PSDZService psdz) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final ecuPanelFlex = isNarrow ? 1 : 2;
        final filesPanelFlex = isNarrow ? 1 : 3;

        return Column(
          children: [
            // Header Configuration
            _buildConfigSection(psdz),
            const SizedBox(height: 16),

            // Main Content - responsive layout
            Expanded(
              child: isNarrow
                  ? Column(
                      children: [
                        Expanded(child: _buildECUPanel(psdz)),
                        const SizedBox(height: 12),
                        Expanded(child: _buildFilesPanel(psdz)),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel - ECU List (responsive width)
                        Flexible(
                            flex: ecuPanelFlex, child: _buildECUPanel(psdz)),
                        const SizedBox(width: 16),

                        // Right Panel - Files
                        Flexible(
                            flex: filesPanelFlex,
                            child: _buildFilesPanel(psdz)),
                      ],
                    ),
            ),

            // Footer - Actions
            const SizedBox(height: 16),
            _buildActionBar(psdz),
          ],
        );
      },
    );
  }

  Widget _buildTALImportTab(PSDZService psdz) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // TAL/SVT Import Controls
        GlassCard(
          title: '📥 TAL/SVT File Import',
          icon: FluentIcons.download,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: TextEditingController(
                        text: psdz.currentTALFile?.path ?? '',
                      ),
                      placeholder: 'Select TAL or SVT file...',
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    child: const Text('Browse...'),
                    onPressed: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['xml', 'tal', 'svt'],
                          dialogTitle: 'Select TAL or SVT File',
                        );

                        if (result != null && result.files.isNotEmpty) {
                          final path = result.files.first.path;
                          if (path != null) {
                            await psdz.loadTALFile(path);
                            if (mounted) setState(() {});
                          }
                        }
                      } catch (e) {
                        debugPrint('Error picking file: $e');
                        // Fallback to any file type if custom fails
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                            dialogTitle: 'Select TAL or SVT File (Any)',
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final path = result.files.first.path;
                            if (path != null) {
                              await psdz.loadTALFile(path);
                              if (mounted) setState(() {});
                            }
                          }
                        } catch (e2) {
                          debugPrint('Error picking file (fallback): $e2');
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    child: Row(
                      children: [
                        if (psdz.isLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        else
                          const Icon(FluentIcons.open_file, size: 14),
                        const SizedBox(width: 6),
                        const Text('Load File'),
                      ],
                    ),
                    onPressed: psdz.isLoading
                        ? null
                        : () async {
                            try {
                              final result =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['xml', 'tal', 'svt'],
                                dialogTitle: 'Select TAL or SVT XML File',
                              );
                              if (result != null && result.files.isNotEmpty) {
                                final path = result.files.first.path;
                                if (path != null && path.isNotEmpty) {
                                  await psdz.loadTALFile(path);
                                  if (mounted) setState(() {});
                                }
                              }
                            } catch (e) {
                              // Fallback
                              final result = await FilePicker.platform
                                  .pickFiles(type: FileType.any);
                              if (result != null && result.files.isNotEmpty) {
                                final path = result.files.first.path;
                                if (path != null) {
                                  await psdz.loadTALFile(path);
                                  if (mounted) setState(() {});
                                }
                              }
                            }
                          },
                  ),
                ],
              ),
              if (psdz.currentTALFile != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AQColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AQColors.primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildInfoBadge(
                        'Type',
                        psdz.currentTALFile!.type.name.toUpperCase(),
                      ),
                      const SizedBox(width: 16),
                      _buildInfoBadge('VIN', psdz.currentTALFile!.vin ?? 'N/A'),
                      const SizedBox(width: 16),
                      _buildInfoBadge(
                        'Series',
                        psdz.currentTALFile!.series ?? 'N/A',
                      ),
                      const SizedBox(width: 16),
                      _buildInfoBadge(
                        'I-Step',
                        psdz.currentTALFile!.iStep ?? 'N/A',
                      ),
                      const SizedBox(width: 16),
                      _buildInfoBadge(
                        'ECUs',
                        '${psdz.currentTALFile!.ecus.length}',
                      ),
                      const SizedBox(width: 16),
                      // Show found/missing files count
                      _buildInfoBadge(
                        'Files',
                        '${_countFoundFiles(psdz.currentTALFile!.ecus)}/${_countTotalFiles(psdz.currentTALFile!.ecus)}',
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          FluentIcons.open_in_new_window,
                          size: 14,
                        ),
                        onPressed: () =>
                            _revealInExplorer(psdz.currentTALFile!.path),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        child: const Row(
                          children: [
                            Icon(FluentIcons.edit, size: 14),
                            SizedBox(width: 6),
                            Text('Edit'),
                          ],
                        ),
                        onPressed: () =>
                            _openInTalEditor(psdz, psdz.currentTALFile!.path),
                      ),
                      const SizedBox(width: 8),
                      DropDownButton(
                        title: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.download, size: 14),
                            SizedBox(width: 6),
                            Text('Extract'),
                          ],
                        ),
                        items: [
                          MenuFlyoutItem(
                            leading: const Icon(FluentIcons.folder, size: 14),
                            text: const Text('Extract PSDZDATA (keep paths)'),
                            onPressed: () => _extractCurrentTal(
                              psdz,
                              preserveStructure: true,
                              title: 'Extracting PSDZDATA',
                            ),
                          ),
                          MenuFlyoutItem(
                            leading: const Icon(FluentIcons.group, size: 14),
                            text: const Text('Extract grouped by ECU'),
                            onPressed: () => _extractCurrentTal(
                              psdz,
                              preserveStructure: false,
                              title: 'Extracting (by ECU)',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ECU List from TAL/SVT with file details
        Expanded(
          child: psdz.currentTALFile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FluentIcons.download,
                        size: 64,
                        color: isDark
                            ? AQColors.textSecondary
                            : AQColors.lightTextMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Load a TAL or SVT file to see ECUs',
                        style: TextStyle(
                          color: isDark
                              ? AQColors.textPrimary
                              : AQColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: psdz.currentTALFile!.ecus.length,
                  itemBuilder: (context, index) {
                    final ecu = psdz.currentTALFile!.ecus[index];
                    final foundCount = ecu.files
                        .where((f) => f.status == FileStatus.found)
                        .length;
                    final totalCount = ecu.files.length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FluentTheme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: foundCount == totalCount
                              ? AQColors.success.withOpacity(0.5)
                              : foundCount > 0
                                  ? Colors.orange.withOpacity(0.5)
                                  : AQColors.secondaryRed.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AQColors.primaryBlue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ecu.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                ecu.addressHex,
                                style: TextStyle(
                                  color: isDark
                                      ? AQColors.textSecondary
                                      : AQColors.lightTextSecondary,
                                  fontFamily: 'Consolas',
                                ),
                              ),
                              const Spacer(),
                              // Show found/total files
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: foundCount == totalCount
                                      ? AQColors.success
                                      : foundCount > 0
                                          ? Colors.orange
                                          : AQColors.secondaryRed,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$foundCount/$totalCount files',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: ecu.files
                                .map(
                                  (f) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: f.status == FileStatus.found
                                          ? AQColors.success.withOpacity(0.3)
                                          : AQColors.secondaryRed.withOpacity(
                                              0.3,
                                            ),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: f.status == FileStatus.found
                                            ? AQColors.success
                                            : AQColors.secondaryRed,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          f.status == FileStatus.found
                                              ? FluentIcons.check_mark
                                              : FluentIcons.error_badge,
                                          size: 10,
                                          color: f.status == FileStatus.found
                                              ? AQColors.success
                                              : AQColors.secondaryRed,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${f.processClass}:${f.id}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Consolas',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  int _countFoundFiles(List<ECU> ecus) {
    int count = 0;
    for (var ecu in ecus) {
      count += ecu.files.where((f) => f.status == FileStatus.found).length;
    }
    return count;
  }

  int _countTotalFiles(List<ECU> ecus) {
    int count = 0;
    for (var ecu in ecus) {
      count += ecu.files.length;
    }
    return count;
  }

  /// Auto-Scan Tab - Scan C:/data for FA, SVT, TAL files with VIN matching
  Widget _buildAutoScanTab(PSDZService psdz) {
    // Filter matched vehicles
    final filteredVehicles = psdz.matchedVehicles.where((v) {
      if (_vinSearchQuery.isNotEmpty &&
          !v.vin.toLowerCase().contains(_vinSearchQuery.toLowerCase())) {
        return false;
      }
      if (_seriesSearchQuery.isNotEmpty &&
          (v.series == null ||
              !v.series!.toLowerCase().contains(
                    _seriesSearchQuery.toLowerCase(),
                  ))) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Auto-Scan Config
        GlassCard(
          title: '🚗 Auto-Scan C:/data - Vehicle Discovery',
          icon: FluentIcons.car,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text(
                      'Scan Path:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: TextBox(
                      controller: TextEditingController(
                        text: psdz.autoScanPath,
                      ),
                      onChanged: (value) => psdz.autoScanPath = value,
                      placeholder: 'C:/data',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    child: const Text('Browse'),
                    onPressed: () async {
                      final result = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Select Data Folder to Scan',
                      );
                      if (result != null) {
                        psdz.autoScanPath = result;
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (psdz.isLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        else
                          const Icon(FluentIcons.search, size: 14),
                        const SizedBox(width: 6),
                        const Text('Auto-Scan'),
                      ],
                    ),
                    onPressed:
                        psdz.isLoading ? null : () => psdz.autoScanDataFolder(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Statistics row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AQColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AQColors.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    _buildSimpleStatBadge(
                      'FA Files',
                      '${psdz.faFiles.length}',
                      AQColors.primaryBlue,
                    ),
                    const SizedBox(width: 16),
                    _buildSimpleStatBadge(
                      'SVT Files',
                      '${psdz.svtFiles.length}',
                      AQColors.success,
                    ),
                    const SizedBox(width: 16),
                    _buildSimpleStatBadge(
                      'TAL Files',
                      '${psdz.talFilesScanned.length}',
                      Colors.orange,
                    ),
                    const SizedBox(width: 16),
                    _buildSimpleStatBadge(
                      'Matched Vehicles',
                      '${psdz.matchedVehicles.length}',
                      AQColors.secondaryRed,
                    ),
                    const Spacer(),
                    // Filter controls
                    SizedBox(
                      width: 150,
                      child: TextBox(
                        placeholder: 'Filter by VIN...',
                        onChanged: (value) =>
                            setState(() => _vinSearchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextBox(
                        placeholder: 'Series...',
                        onChanged: (value) =>
                            setState(() => _seriesSearchQuery = value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Main content - Matched Vehicles and Selected Vehicle Details
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left - Matched Vehicles List
              SizedBox(
                width: 400,
                child: GlassCard(
                  title: '🚙 Matched Vehicles (${filteredVehicles.length})',
                  icon: FluentIcons.car,
                  expand: true,
                  child: ListView.builder(
                    itemCount: filteredVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = filteredVehicles[index];
                      final isSelected =
                          psdz.selectedVehicle?.vin == vehicle.vin;
                      final isDarkVehicle =
                          FluentTheme.of(context).brightness == Brightness.dark;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AQColors.primaryBlue.withOpacity(0.2)
                              : (isDarkVehicle
                                  ? AQColors.cardBackground
                                  : AQColors.lightCardBackground),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? AQColors.primaryBlue
                                : (vehicle.isComplete
                                    ? AQColors.success
                                    : Colors.orange),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          onPressed: () => psdz.selectMatchedVehicle(vehicle),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: vehicle.isComplete
                                  ? AQColors.success
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              vehicle.isComplete
                                  ? FluentIcons.check_mark
                                  : FluentIcons.warning,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            vehicle.vinShort,
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: FluentTheme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : AQColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Series: ${vehicle.series ?? "Unknown"}',
                                style: TextStyle(
                                  color: FluentTheme.of(context).brightness ==
                                          Brightness.dark
                                      ? AQColors.textSecondary
                                      : AQColors.lightTextSecondary,
                                ),
                              ),
                              Row(
                                children: [
                                  if (vehicle.hasFA)
                                    _buildFileIndicator(
                                      'FA',
                                      AQColors.primaryBlue,
                                    ),
                                  if (vehicle.hasSVT)
                                    _buildFileIndicator(
                                      'SVT',
                                      AQColors.success,
                                    ),
                                  if (vehicle.hasTAL)
                                    _buildFileIndicator(
                                      'TAL×${vehicle.talFiles.length}',
                                      Colors.orange,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Right - Selected Vehicle Details
              Expanded(
                child: psdz.selectedVehicle == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FluentIcons.car,
                              size: 64,
                              color: FluentTheme.of(context).brightness ==
                                      Brightness.dark
                                  ? AQColors.textSecondary
                                  : AQColors.lightTextMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select a vehicle to view details',
                              style: TextStyle(
                                color: FluentTheme.of(context).brightness ==
                                        Brightness.dark
                                    ? AQColors.textPrimary
                                    : AQColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Run Auto-Scan to discover FA, SVT, TAL files',
                              style: TextStyle(
                                color: FluentTheme.of(context).brightness ==
                                        Brightness.dark
                                    ? AQColors.textSecondary
                                    : AQColors.lightTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GlassCard(
                        title: '📋 Vehicle: ${psdz.selectedVehicle!.vin}',
                        icon: FluentIcons.info,
                        expand: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Vehicle info header
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: FluentTheme.of(context).brightness ==
                                        Brightness.dark
                                    ? AQColors.primaryBlue.withOpacity(0.1)
                                    : AQColors.lightSurfaceBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: FluentTheme.of(context).brightness ==
                                        Brightness.light
                                    ? Border.all(color: AQColors.lightBorder)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  _buildInfoBadge(
                                    'VIN',
                                    psdz.selectedVehicle!.vin,
                                  ),
                                  const SizedBox(width: 16),
                                  _buildInfoBadge(
                                    'Series',
                                    psdz.selectedVehicle!.series ?? 'N/A',
                                  ),
                                  const SizedBox(width: 16),
                                  _buildInfoBadge(
                                    'I-Step',
                                    psdz.selectedVehicle!.istep ?? 'N/A',
                                  ),
                                  const Spacer(),
                                  if (psdz.selectedVehicle!.svtFile !=
                                      null) ...[
                                    FilledButton(
                                      child: const Row(
                                        children: [
                                          Icon(FluentIcons.edit, size: 14),
                                          SizedBox(width: 6),
                                          Text('Edit SVT'),
                                        ],
                                      ),
                                      onPressed: () => _openInTalEditor(
                                        psdz,
                                        psdz.selectedVehicle!.svtFile!.path,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (psdz.selectedVehicle!.talFiles
                                      .isNotEmpty) ...[
                                    if (psdz.selectedVehicle!.talFiles.length ==
                                        1)
                                      FilledButton(
                                        child: const Row(
                                          children: [
                                            Icon(FluentIcons.edit, size: 14),
                                            SizedBox(width: 6),
                                            Text('Edit TAL'),
                                          ],
                                        ),
                                        onPressed: () => _openInTalEditor(
                                          psdz,
                                          psdz.selectedVehicle!.talFiles.first
                                              .path,
                                        ),
                                      )
                                    else
                                      DropDownButton(
                                        title: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(FluentIcons.edit, size: 14),
                                            SizedBox(width: 6),
                                            Text('Edit TAL'),
                                          ],
                                        ),
                                        items: [
                                          for (final tal
                                              in psdz.selectedVehicle!.talFiles)
                                            MenuFlyoutItem(
                                              text: Text(tal.filename),
                                              onPressed: () => _openInTalEditor(
                                                psdz,
                                                tal.path,
                                              ),
                                            ),
                                        ],
                                      ),
                                    const SizedBox(width: 8),
                                  ],
                                  DropDownButton(
                                    title: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(FluentIcons.download, size: 14),
                                        SizedBox(width: 6),
                                        Text('Extract'),
                                      ],
                                    ),
                                    items: [
                                      MenuFlyoutItem(
                                        leading: const Icon(
                                          FluentIcons.folder,
                                          size: 14,
                                        ),
                                        text: const Text(
                                          'Extract PSDZDATA (keep paths)',
                                        ),
                                        onPressed: () => _extractCurrentTal(
                                          psdz,
                                          preserveStructure: true,
                                          defaultSubfolder:
                                              psdz.selectedVehicle!.vinShort,
                                          title: 'Extracting Vehicle PSDZDATA',
                                        ),
                                      ),
                                      MenuFlyoutItem(
                                        leading: const Icon(
                                          FluentIcons.group,
                                          size: 14,
                                        ),
                                        text: const Text(
                                          'Extract grouped by ECU',
                                        ),
                                        onPressed: () => _extractCurrentTal(
                                          psdz,
                                          preserveStructure: false,
                                          defaultSubfolder:
                                              psdz.selectedVehicle!.vinShort,
                                          title: 'Extracting Vehicle (by ECU)',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Files from vehicle
                            Text(
                              'Associated Files:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: FluentTheme.of(context).brightness ==
                                        Brightness.dark
                                    ? AQColors.textSecondary
                                    : AQColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // FA File
                            if (psdz.selectedVehicle!.faFile != null)
                              _buildFileRow(
                                'FA',
                                psdz.selectedVehicle!.faFile!,
                              ),

                            // SVT File
                            if (psdz.selectedVehicle!.svtFile != null)
                              _buildFileRow(
                                'SVT',
                                psdz.selectedVehicle!.svtFile!,
                              ),

                            // TAL Files
                            for (var tal in psdz.selectedVehicle!.talFiles)
                              _buildFileRow('TAL', tal),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),

                            // ECU list from loaded file
                            if (psdz.currentTALFile != null) ...[
                              Text(
                                'ECUs from ${psdz.currentTALFile!.type.name.toUpperCase()} (${psdz.currentTALFile!.ecus.length}):',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: psdz.currentTALFile!.ecus.length,
                                  itemBuilder: (context, index) {
                                    final ecu =
                                        psdz.currentTALFile!.ecus[index];
                                    final foundCount = ecu.files
                                        .where(
                                          (f) => f.status == FileStatus.found,
                                        )
                                        .length;

                                    final isDarkEcu =
                                        FluentTheme.of(context).brightness ==
                                            Brightness.dark;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDarkEcu
                                            ? AQColors.cardBackground
                                            : AQColors.lightCardBackground,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: foundCount == ecu.files.length
                                              ? AQColors.success.withOpacity(
                                                  0.5,
                                                )
                                              : foundCount > 0
                                                  ? Colors.orange
                                                      .withOpacity(0.5)
                                                  : AQColors.secondaryRed
                                                      .withOpacity(0.5),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AQColors.primaryBlue,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              ecu.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            ecu.addressHex,
                                            style: TextStyle(
                                              fontFamily: 'Consolas',
                                              fontSize: 11,
                                              color: isDarkEcu
                                                  ? AQColors.textSecondary
                                                  : AQColors.lightTextSecondary,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  foundCount == ecu.files.length
                                                      ? AQColors.success
                                                      : Colors.orange,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$foundCount/${ecu.files.length}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ] else
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'No SVT/TAL file loaded',
                                    style: TextStyle(
                                      color:
                                          FluentTheme.of(context).brightness ==
                                                  Brightness.dark
                                              ? AQColors.textSecondary
                                              : AQColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileRow(String type, VehicleFile file) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: type == 'FA'
                  ? AQColors.primaryBlue
                  : (type == 'SVT' ? AQColors.success : Colors.orange),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              type,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              file.filename,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (file.ecuCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    (isDark ? AQColors.textSecondary : AQColors.lightTextMuted)
                        .withOpacity(0.25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${file.ecuCount} ECUs',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(FluentIcons.open_file, size: 14),
            onPressed: () async {
              final psdz = Provider.of<PSDZService>(context, listen: false);
              if (type == 'FA') {
                await psdz.loadFAFile(file.path);
              } else {
                await psdz.loadTALFile(file.path);
              }
            },
          ),
          if (type == 'SVT' || type == 'TAL') ...[
            IconButton(
              icon: const Icon(FluentIcons.edit, size: 14),
              onPressed: () {
                final psdz = Provider.of<PSDZService>(context, listen: false);
                _openInTalEditor(psdz, file.path);
              },
            ),
          ],
          IconButton(
            icon: const Icon(FluentIcons.open_in_new_window, size: 14),
            onPressed: () => _revealInExplorer(file.path),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatBadge(String label, String value, Color color) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileIndicator(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLibraryScanTab(PSDZService psdz) {
    final filteredLibrary = psdz.filterLibrary(
      vin: _libraryFilter,
      series: _librarySeriesFilter,
    );

    return Column(
      children: [
        // Library Scan Controls
        GlassCard(
          title: '📚 Library Scanner',
          icon: FluentIcons.library,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text(
                      'Scan Paths:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: TextBox(
                      controller: TextEditingController(text: psdz.scanPaths),
                      onChanged: (value) => psdz.scanPaths = value,
                      placeholder: 'C:/Data/TAL, C:/Data/SVT',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    child: const Text('Browse'),
                    onPressed: () async {
                      final result = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Select Library Folder',
                      );
                      if (result != null) {
                        final current = psdz.scanPaths.trim();
                        if (current.isEmpty) {
                          psdz.scanPaths = result;
                        } else {
                          psdz.scanPaths = '$current, $result';
                        }
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    child: Row(
                      children: [
                        if (psdz.isLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        else
                          const Icon(FluentIcons.search, size: 14),
                        const SizedBox(width: 6),
                        const Text('Scan'),
                      ],
                    ),
                    onPressed: psdz.isLoading ? null : () => psdz.scanLibrary(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text(
                      'Filter VIN:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextBox(
                      placeholder: 'Enter VIN...',
                      onChanged: (value) =>
                          setState(() => _libraryFilter = value),
                    ),
                  ),
                  const SizedBox(width: 24),
                  const Text(
                    'Series:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextBox(
                      placeholder: 'e.g. G30',
                      onChanged: (value) =>
                          setState(() => _librarySeriesFilter = value),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Found: ${filteredLibrary.length} files',
                    style: TextStyle(
                      color: AQColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Library Results
        Expanded(
          child: psdz.libraryFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FluentIcons.library,
                        size: 64,
                        color: FluentTheme.of(context).brightness ==
                                Brightness.dark
                            ? AQColors.textSecondary
                            : AQColors.lightTextMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scan library paths to find TAL/SVT files',
                        style: TextStyle(
                          color: FluentTheme.of(context).brightness ==
                                  Brightness.dark
                              ? AQColors.textPrimary
                              : AQColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                )
              : GlassCard(
                  title: '📋 Library Files (${filteredLibrary.length})',
                  icon: FluentIcons.document_set,
                  expand: true,
                  child: ListView.builder(
                    itemCount: filteredLibrary.length,
                    itemBuilder: (context, index) {
                      final file = filteredLibrary[index];
                      final typeLabel = (file.type).toUpperCase();
                      final typeColor = typeLabel == 'TAL'
                          ? AQColors.primaryBlue
                          : (typeLabel == 'SVT'
                              ? AQColors.success
                              : Colors.orange);

                      return ListTile.selectable(
                        onPressed: () async {
                          await psdz.loadTALFile(file.path);
                          if (mounted) {
                            setState(() {
                              _currentTab = 1;
                              _importLibraryTab = 0;
                            });
                          }
                        },
                        leading: Icon(
                          typeLabel == 'TAL'
                              ? FluentIcons.task_list
                              : (typeLabel == 'SVT'
                                  ? FluentIcons.document
                                  : FluentIcons.file_code),
                          color: typeLabel == 'TAL'
                              ? AQColors.primaryBlue
                              : (typeLabel == 'SVT'
                                  ? AQColors.success
                                  : Colors.orange),
                        ),
                        title: Text(
                          file.filename,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: FluentTheme.of(context).brightness ==
                                    Brightness.dark
                                ? Colors.white
                                : AQColors.lightTextPrimary,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (file.vin != null)
                              Text(
                                'VIN: ${file.vin}  ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: FluentTheme.of(context).brightness ==
                                          Brightness.dark
                                      ? AQColors.textSecondary
                                      : AQColors.lightTextSecondary,
                                ),
                              ),
                            if (file.series != null)
                              Text(
                                'Series: ${file.series}  ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: FluentTheme.of(context).brightness ==
                                          Brightness.dark
                                      ? AQColors.textSecondary
                                      : AQColors.lightTextSecondary,
                                ),
                              ),
                            Text(
                              'ECUs: ${file.ecuCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: FluentTheme.of(context).brightness ==
                                        Brightness.dark
                                    ? AQColors.textSecondary
                                    : AQColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                FluentIcons.open_in_new_window,
                                size: 14,
                              ),
                              onPressed: () => _revealInExplorer(file.path),
                            ),
                            IconButton(
                              icon: const Icon(FluentIcons.edit, size: 14),
                              onPressed: () {
                                _openInTalEditor(psdz, file.path);
                              },
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                typeLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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
      ],
    );
  }

  Widget _buildInfoBadge(String label, String value) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    // Classic Windows style colors
    final Color bgColor = isDark
        ? AQColors.primaryBlue.withOpacity(0.2)
        : AQColors.lightCardBackground;
    final Border border = Border.all(
      color:
          isDark ? AQColors.primaryBlue.withOpacity(0.5) : AQColors.lightBorder,
      width: isDark ? 1 : 1.5,
    );
    final Color labelColor =
        isDark ? AQColors.textSecondary : AQColors.lightTextPrimary;
    final Color valueColor = isDark ? AQColors.accentCyan : AQColors.mBlue;

    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: labelColor,
            fontSize: 11,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(2),
            border: border,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(1, 1),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontFamily: 'Consolas',
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigSection(PSDZService psdz) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Side - Compact Configuration
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AQColors.cardBackground
                  : AQColors.lightCardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? AQColors.primaryBlue.withOpacity(0.3)
                    : AQColors.primaryBlue.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONFIGURATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InfoLabel(
                        label: 'Series',
                        labelStyle: const TextStyle(fontSize: 11),
                        child: ComboBox<String>(
                          value: psdz.selectedSeries,
                          isExpanded: true,
                          placeholder: const Text('Select Series'),
                          items: psdz.series
                              .map(
                                (s) => ComboBoxItem(
                                  value: s.code,
                                  child: Text(s.code),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) psdz.selectSeries(v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InfoLabel(
                        label: 'I-Step',
                        labelStyle: const TextStyle(fontSize: 11),
                        child: ComboBox<String>(
                          value: psdz.selectedIStep,
                          isExpanded: true,
                          placeholder: const Text('Select I-Step'),
                          items: psdz.iSteps
                              .map(
                                (i) => ComboBoxItem(
                                  value: i.name,
                                  child: Text(i.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) psdz.selectIStep(v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Right Side - Status & Details (Separate Bar)
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8EBF2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SYSTEM STATUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    // Version Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AQColors.primaryBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        psdz.psdzVersion.isEmpty
                            ? 'Scanning...'
                            : psdz.psdzVersion,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusItem(
                      'ECUs',
                      '${psdz.ecus.length}',
                      FluentIcons.processing,
                      isDark,
                    ),
                    const SizedBox(width: 16),
                    _buildStatusItem(
                      'Files',
                      '${psdz.fileCount}',
                      FluentIcons.file_code,
                      isDark,
                    ),
                    const SizedBox(width: 16),
                    _buildStatusItem(
                      'Size',
                      psdz.psdzSize,
                      FluentIcons.hard_drive,
                      isDark,
                    ),
                    const Spacer(),
                    if (psdz.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? AQColors.textSecondary : AQColors.lightTextSecondary,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildECUPanel(PSDZService psdz) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    final filteredECUs = _ecuSearchQuery.isEmpty
        ? psdz.ecus
        : psdz.ecus
            .where(
              (e) => e.name.toLowerCase().contains(
                    _ecuSearchQuery.toLowerCase(),
                  ),
            )
            .toList();

    return GlassCard(
      title: '🔧 ECUs (${filteredECUs.length})',
      icon: FluentIcons.processing,
      expand: true,
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextBox(
                    placeholder: 'Search ECU...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 14),
                    ),
                    onChanged: (value) =>
                        setState(() => _ecuSearchQuery = value),
                    decoration: WidgetStateProperty.all(
                      BoxDecoration(
                        color: isDark
                            ? AQColors.surfaceBackground
                            : AQColors.lightSurfaceBackground,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark
                              ? Colors.transparent
                              : Colors.black.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Export List',
                  child: IconButton(
                    icon: const Icon(
                      FluentIcons.share,
                      size: 16,
                      color: AQColors.accentCyan,
                    ),
                    onPressed: () {
                      // Export logic placeholder
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ECU List
          Expanded(
            child: psdz.isLoading && psdz.ecus.isEmpty
                ? const Center(child: ProgressRing())
                : ListView.builder(
                    itemCount: filteredECUs.length,
                    itemBuilder: (context, index) {
                      final ecu = filteredECUs[index];
                      final isSelected = ecu.name == psdz.selectedECU;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile.selectable(
                          selected: isSelected,
                          onPressed: () => psdz.selectECU(ecu.name),
                          leading: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ecu.files.isNotEmpty
                                  ? AQColors.success
                                  : AQColors.textSecondary,
                              shape: BoxShape.circle,
                              boxShadow: ecu.files.isNotEmpty
                                  ? [
                                      BoxShadow(
                                        color: AQColors.success.withOpacity(
                                          0.4,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          title: Text(
                            ecu.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? AQColors.primaryBlue : null,
                            ),
                          ),
                          subtitle: Text(
                            '${ecu.addressHex} • ${ecu.files.length} files',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AQColors.textSecondary
                                  : AQColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesPanel(PSDZService psdz) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    final filteredFiles = _fileTypeFilter == 'ALL'
        ? psdz.files
        : psdz.files.where((f) => f.processClass == _fileTypeFilter).toList();

    return GlassCard(
      title: '📁 ECU Files (${filteredFiles.length})',
      icon: FluentIcons.document_set,
      expand: true,
      child: Column(
        children: [
          // Filter Toolbar
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Type:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['ALL', 'SWFL', 'CAFD', 'BTLD', 'FLSL'].map((
                        type,
                      ) {
                        final isSelected = _fileTypeFilter == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _fileTypeFilter = type),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AQColors.primaryBlue
                                    : (isDark
                                        ? AQColors.surfaceBackground
                                        : AQColors.lightSurfaceBackground),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AQColors.primaryBlue
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AQColors.textSecondary
                                          : AQColors.lightTextSecondary),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Files table
          Expanded(
            child: psdz.isLoading && psdz.files.isEmpty
                ? const Center(child: ProgressRing())
                : filteredFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FluentIcons.folder_open,
                              size: 48,
                              color: isDark
                                  ? AQColors.textSecondary
                                  : AQColors.lightTextMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select an ECU to view files',
                              style: TextStyle(
                                color: isDark
                                    ? AQColors.textPrimary
                                    : AQColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredFiles.length,
                        itemBuilder: (context, index) {
                          final file = filteredFiles[index];
                          final isFound = file.status == FileStatus.found;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AQColors.textSecondary.withOpacity(0.2)
                                  : AQColors.lightSurfaceBackground,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isFound
                                    ? AQColors.success.withOpacity(0.3)
                                    : AQColors.secondaryRed.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Status icon
                                Icon(
                                  isFound
                                      ? FluentIcons.check_mark
                                      : FluentIcons.error_badge,
                                  size: 14,
                                  color: isFound
                                      ? AQColors.success
                                      : AQColors.secondaryRed,
                                ),
                                const SizedBox(width: 12),

                                // Type badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AQColors.primaryBlue,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    file.processClass,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // File ID
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    file.id,
                                    style: TextStyle(
                                      fontFamily: 'Consolas',
                                      color: isDark
                                          ? AQColors.textPrimary
                                          : AQColors.lightTextPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Version
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    file.version,
                                    style: TextStyle(
                                      color: isDark
                                          ? AQColors.textSecondary
                                          : AQColors.lightTextSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                                // Path
                                Expanded(
                                  child: Text(
                                    file.path ?? 'Not found',
                                    style: TextStyle(
                                      color: isFound
                                          ? (isDark
                                              ? AQColors.textPrimary
                                              : AQColors.lightTextPrimary)
                                          : AQColors.secondaryRed,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(PSDZService psdz) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final stats = psdz.getStatistics();
    final foundCount = stats['foundFiles'] ?? 0;
    final missingCount = stats['missingFiles'] ?? 0;
    final totalCount = foundCount + missingCount;
    final progressPercent =
        totalCount > 0 ? (foundCount / totalCount * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AQColors.surfaceBackground
            : AQColors.lightSurfaceBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? AQColors.primaryBlue.withOpacity(0.2)
              : AQColors.primaryBlue.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Status Section
          Expanded(
            child: Row(
              children: [
                // Loading indicator or status icon
                if (psdz.isLoading)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10),
                    child: const ProgressRing(strokeWidth: 2),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AQColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      FluentIcons.check_mark,
                      size: 12,
                      color: AQColors.success,
                    ),
                  ),
                // Status message
                Expanded(
                  child: Text(
                    psdz.statusMessage,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AQColors.textSecondary
                          : AQColors.lightTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                // Statistics badges
                _buildStatBadge(
                  'Found',
                  '$foundCount',
                  AQColors.success,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  'Missing',
                  '$missingCount',
                  AQColors.secondaryRed,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  '$progressPercent%',
                  null,
                  AQColors.primaryBlue,
                  isDark,
                  isProgress: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // M Stripes separator
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: AQColors.mStripesGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          // Action buttons
          _buildActionButton(
            icon: FluentIcons.paste,
            label: 'List',
            onPressed:
                psdz.ecus.isEmpty ? null : () => _exportEcuListTxt(context),
            isDark: isDark,
          ),
          const SizedBox(width: 6),
          _buildActionButton(
            icon: FluentIcons.table,
            label: 'CSV',
            onPressed:
                psdz.ecus.isEmpty ? null : () => _exportEcuListCsv(context),
            isDark: isDark,
          ),
          const SizedBox(width: 6),
          _buildActionButton(
            icon: FluentIcons.download,
            label: 'Selected',
            onPressed: psdz.files.isEmpty
                ? null
                : () async {
                    final result = await FilePicker.platform.getDirectoryPath(
                      dialogTitle: 'Select Output Folder',
                    );
                    if (result != null && context.mounted) {
                      final filesToExtract = psdz.files
                          .where((f) => f.status == FileStatus.found)
                          .toList();
                      await showFluentDialog(
                        context: context,
                        builder: (ctx) => ProgressDialog(
                          title: 'Extracting Files',
                          future: _preserveStructure
                              ? psdz.extractFilesWithStructure(
                                  filesToExtract,
                                  '$result/${psdz.selectedECU ?? "files"}',
                                )
                              : psdz.extractFiles(
                                  filesToExtract,
                                  '$result/${psdz.selectedECU ?? "files"}',
                                ),
                        ),
                      );
                    }
                  },
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          // Main Extract Button
          Container(
            height: 32,
            decoration: BoxDecoration(
              gradient: AQColors.primaryGradient,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AQColors.primaryBlue.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _preserveStructure
                        ? FluentIcons.folder
                        : FluentIcons.download,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _preserveStructure ? 'Extract Structured' : 'Extract All',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              onPressed: psdz.files.isEmpty
                  ? null
                  : () async {
                      final result = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Select Output Folder',
                      );
                      if (result != null && context.mounted) {
                        final filesToExtract = psdz.files
                            .where((f) => f.status == FileStatus.found)
                            .toList();
                        await showFluentDialog(
                          context: context,
                          builder: (ctx) => ProgressDialog(
                            title: _preserveStructure
                                ? 'Extracting with Folder Structure'
                                : 'Extracting Files',
                            future: _preserveStructure
                                ? psdz.extractFilesWithStructure(
                                    filesToExtract,
                                    '$result/${psdz.selectedECU ?? "files"}',
                                  )
                                : psdz.extractFiles(
                                    filesToExtract,
                                    '$result/${psdz.selectedECU ?? "files"}',
                                  ),
                          ),
                        );
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(
    String label,
    String? value,
    Color color,
    bool isDark, {
    bool isProgress = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            value ?? label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    return SizedBox(
      height: 28,
      child: Button(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  /// Backup Browser Tab - Browse C:\Data\Backup folder
  Widget _buildBackupBrowserTab(PSDZService psdz) {
    // Get unique series from backup vehicles
    final allSeries = <String>{'ALL'};
    for (var v in _backupScanner.vehicles) {
      allSeries.add(v.series);
    }

    // Filter vehicles
    final filteredVehicles = _backupScanner.vehicles.where((v) {
      if (_backupSeriesFilter != 'ALL' && v.series != _backupSeriesFilter) {
        return false;
      }
      if (_backupSearchQuery.isNotEmpty) {
        final query = _backupSearchQuery.toLowerCase();
        return v.vin.toLowerCase().contains(query) ||
            v.series.toLowerCase().contains(query) ||
            (v.vehicleName?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Header - Backup Scan Controls
        GlassCard(
          title: '💾 Backup Browser - C:\\Data\\Backup',
          icon: FluentIcons.hard_drive,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'Path:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: TextBox(
                      controller: TextEditingController(
                        text: _backupScanner.backupPath,
                      ),
                      onChanged: (v) => _backupScanner.backupPath = v,
                      placeholder: 'C:\\Data\\Backup',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    child: const Text('Browse'),
                    onPressed: () async {
                      final result = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Select Backup Folder',
                      );
                      if (result != null) {
                        _backupScanner.backupPath = result;
                        await _scanBackupFolder();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_backupScanner.isScanning)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        else
                          const Icon(FluentIcons.search, size: 14),
                        const SizedBox(width: 6),
                        const Text('Scan'),
                      ],
                    ),
                    onPressed:
                        _backupScanner.isScanning ? null : _scanBackupFolder,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats and filters
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AQColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AQColors.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    _buildSimpleStatBadge(
                      'Vehicles',
                      '${_backupScanner.vehicles.length}',
                      AQColors.primaryBlue,
                    ),
                    const SizedBox(width: 16),
                    _buildSimpleStatBadge(
                      'Series',
                      '${allSeries.length - 1}',
                      AQColors.success,
                    ),
                    const SizedBox(width: 16),
                    _buildSimpleStatBadge(
                      'With FA',
                      '${_backupScanner.vehicles.where((v) => v.hasFA).length}',
                      Colors.orange,
                    ),
                    const SizedBox(width: 16),
                    _buildSimpleStatBadge(
                      'With SVT',
                      '${_backupScanner.vehicles.where((v) => v.hasSVT).length}',
                      AQColors.secondaryRed,
                    ),
                    const Spacer(),
                    // Filter
                    const Text(
                      'Series: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      width: 100,
                      child: ComboBox<String>(
                        value: _backupSeriesFilter,
                        isExpanded: true,
                        items: allSeries
                            .map((s) => ComboBoxItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _backupSeriesFilter = v ?? 'ALL'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: TextBox(
                        placeholder: 'Search VIN...',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(FluentIcons.search, size: 12),
                        ),
                        onChanged: (v) =>
                            setState(() => _backupSearchQuery = v),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Main content
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left - Vehicle list
              SizedBox(
                width: 380,
                child: GlassCard(
                  title: '🚗 Backup Vehicles (${filteredVehicles.length})',
                  icon: FluentIcons.car,
                  expand: true,
                  child: filteredVehicles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FluentIcons.hard_drive,
                                size: 48,
                                color: FluentTheme.of(context).brightness ==
                                        Brightness.dark
                                    ? AQColors.textSecondary
                                    : AQColors.lightTextMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No backup vehicles found',
                                style: TextStyle(
                                  color: FluentTheme.of(context).brightness ==
                                          Brightness.dark
                                      ? AQColors.textPrimary
                                      : AQColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Button(
                                child: const Text('Scan Backup Folder'),
                                onPressed: _scanBackupFolder,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredVehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = filteredVehicles[index];
                            final isSelected =
                                _selectedBackupVehicle?.vin == vehicle.vin;

                            final isDarkBackup =
                                FluentTheme.of(context).brightness ==
                                    Brightness.dark;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AQColors.primaryBlue.withOpacity(0.2)
                                    : (isDarkBackup
                                        ? AQColors.cardBackground
                                        : AQColors.lightCardBackground),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? AQColors.primaryBlue
                                      : (vehicle.isComplete
                                          ? AQColors.success
                                          : Colors.orange),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                onPressed: () => setState(
                                  () => _selectedBackupVehicle = vehicle,
                                ),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: vehicle.isComplete
                                        ? AQColors.success
                                        : Colors.orange,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      vehicle.series,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  vehicle.vinShort,
                                  style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontWeight: FontWeight.bold,
                                    color: isDarkBackup
                                        ? Colors.white
                                        : AQColors.lightTextPrimary,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (vehicle.vehicleName != null)
                                      Text(
                                        vehicle.vehicleName!,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    Row(
                                      children: [
                                        if (vehicle.hasFA)
                                          _buildFileIndicator(
                                            'FA',
                                            AQColors.primaryBlue,
                                          ),
                                        if (vehicle.hasSVT)
                                          _buildFileIndicator(
                                            'SVT',
                                            AQColors.success,
                                          ),
                                        _buildFileIndicator(
                                          'ECU×${vehicle.ecuCount}',
                                          Colors.orange,
                                        ),
                                        _buildFileIndicator(
                                          'NCD×${vehicle.ncdFileCount}',
                                          AQColors.secondaryRed,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Right - Vehicle details
              Expanded(
                child: _selectedBackupVehicle == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FluentIcons.car,
                              size: 64,
                              color: AQColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Select a vehicle to view backup details',
                            ),
                          ],
                        ),
                      )
                    : _buildBackupVehicleDetails(_selectedBackupVehicle!, psdz),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackupVehicleDetails(BackupVehicle vehicle, PSDZService psdz) {
    return GlassCard(
      title: '📋 ${vehicle.displayName}',
      icon: FluentIcons.info,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle info header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AQColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildInfoBadge('VIN', vehicle.vin),
                    const SizedBox(width: 16),
                    _buildInfoBadge('Series', vehicle.series),
                    if (vehicle.iStep != null) ...[
                      const SizedBox(width: 16),
                      _buildInfoBadge('I-Step', vehicle.iStep!),
                    ],
                    if (vehicle.typeKey != null) ...[
                      const SizedBox(width: 16),
                      _buildInfoBadge('Type', vehicle.typeKey!),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Backup Date: ${vehicle.backupDate}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    // Export button
                    Button(
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.download, size: 14),
                          SizedBox(width: 6),
                          Text('Export Vehicle'),
                        ],
                      ),
                      onPressed: () => _exportBackupVehicle(vehicle),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.open_file, size: 14),
                          SizedBox(width: 6),
                          Text('Load to Analyzer'),
                        ],
                      ),
                      onPressed: () {
                        if (vehicle.svtFile != null) {
                          psdz.loadTALFile(vehicle.svtFile!.path);
                        } else if (vehicle.faFile != null) {
                          psdz.loadFAFile(vehicle.faFile!.path);
                        }
                        setState(() => _currentTab = 0);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Files section
          if (vehicle.saCodes.isNotEmpty || vehicle.eCodes.isNotEmpty) ...[
            const Text(
              'FA Codes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var code in vehicle.saCodes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AQColors.primaryBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Consolas',
                      ),
                    ),
                  ),
                for (var code in vehicle.eCodes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'E:$code',
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Consolas',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // ECU List
          const Text(
            'ECUs with NCD Files:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: vehicle.ecus.length,
              itemBuilder: (context, index) {
                final ecu = vehicle.ecus[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AQColors.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ecu.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        ecu.address,
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AQColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${ecu.ncdFiles.length} NCD',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackupVehicle(BackupVehicle vehicle) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Export Folder for ${vehicle.vinShort}',
    );

    if (result != null && mounted) {
      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(
          title: 'Exporting ${vehicle.vinShort}',
          future: _backupScanner.exportVehicle(vehicle, result),
        ),
      );
    }
  }
}
