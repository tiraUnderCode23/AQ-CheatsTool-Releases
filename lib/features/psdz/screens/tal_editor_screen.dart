import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/aq_theme.dart';
import '../services/psdz_service.dart';
import '../services/backup_scanner_service.dart';
import '../models/ecu.dart';
import '../models/tal_file.dart';
import '../widgets/progress_dialog.dart';

class TALEditorScreen extends StatefulWidget {
  const TALEditorScreen({super.key});

  @override
  State<TALEditorScreen> createState() => _TALEditorScreenState();
}

class _TALEditorScreenState extends State<TALEditorScreen> {
  String _libraryFilter = '';
  int? _selectedECUIndex;
  int _currentTab = 0;

  // Settings
  bool _autoMatchEnabled = true;
  bool _showOnlyMissing = false;
  String _fileTypeFilter = 'ALL';

  // Export options
  String _exportPath = '';
  String _exportMode = 'all'; // all, found, selected, byECU
  bool _preserveStructure = true;
  String? _selectedExportECU;

  @override
  void initState() {
    super.initState();
    // Note: Library scan is now triggered manually via button
    // to avoid blocking UI on screen open
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return Consumer<PSDZService>(
      builder: (context, psdz, _) {
        return ScaffoldPage(
          padding: const EdgeInsets.all(16),
          content: Column(
            children: [
              // Header with Back Button
              _buildHeader(isDark),
              const SizedBox(height: 12),
              // Tab Navigation
              _buildTabBar(),
              const SizedBox(height: 12),

              // Tab Content
              Expanded(
                child: IndexedStack(
                  index: _currentTab,
                  children: [
                    _buildTALEditorTab(psdz),
                    _buildLibraryManagerTab(psdz),
                    _buildVersionMatcherTab(psdz),
                    _buildExportTab(psdz),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    // Check if we can go back (opened via Navigator.push)
    final canPop = Navigator.of(context).canPop();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            isDark ? AQColors.cardBackground : AQColors.lightSurfaceBackground,
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
          // Back button - only show if navigated here via push
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
            FluentIcons.edit_note,
            size: 20,
            color: isDark ? AQColors.primaryBlue : AQColors.lightHighlight,
          ),
          const SizedBox(width: 8),
          Text(
            'SVT-TAL Editor & Library Manager',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AQColors.textPrimary : AQColors.lightTextPrimary,
            ),
          ),
          const Spacer(),
          // Scan Library Button
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                AQColors.primaryBlue.withOpacity(0.8),
              ),
            ),
            onPressed: () => context.read<PSDZService>().scanLibrary(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.sync, size: 12),
                SizedBox(width: 6),
                Text('Scan Library', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      ('SVT-TAL Editor', FluentIcons.edit),
      ('Library Manager', FluentIcons.library),
      ('Version Matcher', FluentIcons.sync),
      ('Export', FluentIcons.download),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
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
                checked: _currentTab == i,
                onChanged: (_) => setState(() => _currentTab = i),
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
                          fontWeight: _currentTab == i
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
          // Settings dropdown
          DropDownButton(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.settings, size: 14),
                SizedBox(width: 6),
                Text('Settings', style: TextStyle(fontSize: 12)),
              ],
            ),
            items: [
              MenuFlyoutItem(
                leading: Icon(
                  _autoMatchEnabled
                      ? FluentIcons.check_mark
                      : FluentIcons.checkbox,
                ),
                text: const Text('Auto-Match Versions'),
                onPressed: () =>
                    setState(() => _autoMatchEnabled = !_autoMatchEnabled),
              ),
              MenuFlyoutItem(
                leading: Icon(
                  _showOnlyMissing
                      ? FluentIcons.check_mark
                      : FluentIcons.checkbox,
                ),
                text: const Text('Show Only Missing Files'),
                onPressed: () =>
                    setState(() => _showOnlyMissing = !_showOnlyMissing),
              ),
              const MenuFlyoutSeparator(),
              MenuFlyoutSubItem(
                leading: const Icon(FluentIcons.filter),
                text: const Text('File Type Filter'),
                items: (context) => [
                  for (var type in [
                    'ALL',
                    'BTLD',
                    'SWFL',
                    'SWFK',
                    'CAFD',
                    'IBAD',
                  ])
                    MenuFlyoutItem(
                      leading: Icon(
                        _fileTypeFilter == type ? FluentIcons.check_mark : null,
                      ),
                      text: Text(type),
                      onPressed: () => setState(() => _fileTypeFilter = type),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTALEditorTab(PSDZService psdz) {
    return Column(
      children: [
        // Header - File Selection
        _buildFileSelection(psdz),
        const SizedBox(height: 12),

        // Main Content
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left - ECU List from TAL/SVT
              SizedBox(width: 350, child: _buildECUList(psdz)),
              const SizedBox(width: 16),

              // Right - ECU Files & Editor
              Expanded(child: _buildFileEditor(psdz)),
            ],
          ),
        ),

        // Actions
        const SizedBox(height: 16),
        _buildActionBar(psdz),
      ],
    );
  }

  Widget _buildLibraryManagerTab(PSDZService psdz) {
    final filteredLibrary = _libraryFilter.isEmpty
        ? psdz.libraryFiles
        : psdz.libraryFiles
            .where(
              (f) =>
                  f.filename.toLowerCase().contains(
                        _libraryFilter.toLowerCase(),
                      ) ||
                  f.type.toLowerCase().contains(_libraryFilter.toLowerCase()),
            )
            .toList();

    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Search and filter controls (fixed height)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                isDark ? AQColors.cardBackground : AQColors.lightCardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? AQColors.primaryBlue.withOpacity(0.3)
                  : AQColors.lightBorder,
            ),
          ),
          child: Column(
            children: [
              // Title Row
              Row(
                children: [
                  Icon(
                    FluentIcons.library,
                    size: 16,
                    color: isDark ? AQColors.primaryBlue : AQColors.mBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '📚 Library Manager (Auto Scan & Backup)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AQColors.textPrimary
                          : AQColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Scan paths display
              Row(
                children: [
                  Text(
                    'Scan Paths: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark
                          ? AQColors.textSecondary
                          : AQColors.lightTextSecondary,
                    ),
                  ),
                  Expanded(
                    child: TextBox(
                      controller: TextEditingController(text: psdz.scanPaths),
                      onChanged: (value) => psdz.scanPaths = value,
                      placeholder: 'C:/Data/TAL, C:/Data/SVT, C:/data',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AQColors.textPrimary
                            : AQColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Button(
                    child: const Text('Browse'),
                    onPressed: () async {
                      final result = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Select TAL/SVT Library Folder',
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
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextBox(
                      placeholder: 'Search Library (VIN, Filename, Type)...',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(FluentIcons.search, size: 14),
                      ),
                      onChanged: (value) =>
                          setState(() => _libraryFilter = value),
                    ),
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
                          const Icon(FluentIcons.refresh, size: 14),
                        const SizedBox(width: 6),
                        const Text('Scan Library'),
                      ],
                    ),
                    onPressed: psdz.isLoading ? null : () => psdz.scanLibrary(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Stats row
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AQColors.surfaceBackground
                      : AQColors.lightSurfaceBackground,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark
                        ? AQColors.primaryBlue.withOpacity(0.2)
                        : AQColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.info,
                      size: 14,
                      color: isDark
                          ? AQColors.textSecondary
                          : AQColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Found: ${psdz.libraryFiles.length} TAL/SVT files',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: psdz.libraryFiles.isEmpty
                            ? (isDark ? AQColors.warning : Colors.orange)
                            : (isDark ? AQColors.success : AQColors.success),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Filtered: ${filteredLibrary.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AQColors.textMuted
                            : AQColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // File List Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AQColors.cardBackground
                : AQColors.lightSurfaceBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: isDark
                  ? AQColors.primaryBlue.withOpacity(0.3)
                  : AQColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                FluentIcons.list,
                size: 14,
                color: isDark ? AQColors.primaryBlue : AQColors.mBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'File List (${filteredLibrary.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color:
                      isDark ? AQColors.textPrimary : AQColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
        // File List (Expanded)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AQColors.surfaceBackground.withOpacity(0.5)
                  : AQColors.lightBackground,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              border: Border(
                left: BorderSide(
                  color: isDark
                      ? AQColors.primaryBlue.withOpacity(0.3)
                      : AQColors.lightBorder,
                ),
                right: BorderSide(
                  color: isDark
                      ? AQColors.primaryBlue.withOpacity(0.3)
                      : AQColors.lightBorder,
                ),
                bottom: BorderSide(
                  color: isDark
                      ? AQColors.primaryBlue.withOpacity(0.3)
                      : AQColors.lightBorder,
                ),
              ),
            ),
            child: filteredLibrary.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.folder_open,
                          size: 64,
                          color: isDark
                              ? AQColors.textMuted
                              : AQColors.lightTextMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No TAL/SVT files found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AQColors.textPrimary
                                : AQColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. Set the scan path above (e.g., C:/data)\n2. Click "Scan Library" button\n3. Or use "Browse" to select a folder',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AQColors.textSecondary
                                : AQColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.folder_search, size: 14),
                              SizedBox(width: 6),
                              Text('Scan C:/data'),
                            ],
                          ),
                          onPressed: () {
                            psdz.scanPaths = 'C:/data';
                            psdz.scanLibrary();
                          },
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredLibrary.length,
                    itemBuilder: (context, index) {
                      final file = filteredLibrary[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AQColors.cardBackground
                              : AQColors.lightCardBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark
                                ? AQColors.primaryBlue.withOpacity(0.2)
                                : AQColors.lightBorder,
                          ),
                        ),
                        child: ListTile.selectable(
                          onPressed: () async {
                            if (file.type == 'TAL' || file.type == 'SVT') {
                              await psdz.loadTALFile(file.path);
                              setState(() {
                                _currentTab = 0; // Switch to Editor
                                _selectedECUIndex = null;
                              });
                            }
                          },
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getFileTypeColor(file.type),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              file.type,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          title: Text(
                            file.filename,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isDark
                                  ? AQColors.textPrimary
                                  : AQColors.lightTextPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${file.vin ?? 'No VIN'} • ${file.series ?? 'Unknown'} • ${file.ecuCount} ECUs\n${file.path}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AQColors.textSecondary
                                  : AQColors.lightTextSecondary,
                            ),
                          ),
                          trailing: (file.type == 'TAL' || file.type == 'SVT')
                              ? FilledButton(
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                      AQColors.primaryBlue,
                                    ),
                                  ),
                                  child: const Text(
                                    'Load',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () async {
                                    await psdz.loadTALFile(file.path);
                                    setState(() {
                                      _currentTab = 0;
                                      _selectedECUIndex = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Color _getFileTypeColor(String type) {
    switch (type) {
      case 'TAL':
        return AQColors.primaryBlue;
      case 'SVT':
        return AQColors.success;
      case 'FA':
        return Colors.orange;
      case 'BACKUP':
        return Colors.purple;
      case 'CAFD':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildVersionMatcherTab(PSDZService psdz) {
    final ecus = psdz.currentTALFile?.ecus ?? [];

    return Column(
      children: [
        GlassCard(
          title: '🔄 Automatic Version Matching',
          icon: FluentIcons.sync,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This tool automatically finds the best matching versions for all files based on available PSDZ data.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
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
                          const Icon(FluentIcons.sync, size: 14),
                        const SizedBox(width: 6),
                        const Text('Match All ECU Versions'),
                      ],
                    ),
                    onPressed: psdz.isLoading
                        ? null
                        : () => _matchAllVersionsForService(psdz),
                  ),
                  const SizedBox(width: 12),
                  Button(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.clear, size: 14),
                        SizedBox(width: 6),
                        Text('Reset to Original'),
                      ],
                    ),
                    onPressed: () => _resetVersions(psdz),
                  ),
                  const Spacer(),
                  if (psdz.currentTALFile != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AQColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Loaded: ${psdz.currentTALFile!.filename}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ecus.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FluentIcons.sync,
                        size: 64,
                        color: AQColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      const Text('Load a TAL/SVT file to match versions'),
                    ],
                  ),
                )
              : GlassCard(
                  title: '📋 Version Match Results',
                  icon: FluentIcons.list,
                  expand: true,
                  child: ListView.builder(
                    itemCount: ecus.length,
                    itemBuilder: (context, index) {
                      final ecu = ecus[index];
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
                        child: Row(
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
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              ecu.addressHex,
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
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
                                              ? AQColors.success.withOpacity(
                                                  0.2,
                                                )
                                              : AQColors.secondaryRed
                                                  .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '${f.processClass}:${f.version}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'Consolas',
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: foundCount == totalCount
                                    ? AQColors.success
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$foundCount/$totalCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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

  Widget _buildExportTab(PSDZService psdz) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final ecus = psdz.currentTALFile?.ecus ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel - Export Options
        SizedBox(
          width: 340,
          child: GlassCard(
            title: '📤 Export Configuration',
            icon: FluentIcons.settings,
            expand: true,
            child: ListView(
              children: [
                // Export Path
                Text(
                  'Export Destination',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AQColors.textPrimary
                        : AQColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextBox(
                        controller: TextEditingController(text: _exportPath),
                        onChanged: (v) => _exportPath = v,
                        placeholder: 'Select export folder...',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Button(
                      child: const Icon(FluentIcons.folder_open, size: 14),
                      onPressed: () async {
                        final result =
                            await FilePicker.platform.getDirectoryPath(
                          dialogTitle: 'Select Export Folder',
                        );
                        if (result != null) {
                          setState(() => _exportPath = result);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Export Mode Selection
                Text(
                  'Export Mode',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AQColors.textPrimary
                        : AQColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildExportModeOption(
                  'all',
                  'Export All Files',
                  FluentIcons.select_all,
                  'Export all files from TAL/SVT',
                  isDark,
                ),
                _buildExportModeOption(
                  'found',
                  'Export Found Only',
                  FluentIcons.check_mark,
                  'Only files matched in PSDZ',
                  isDark,
                ),
                _buildExportModeOption(
                  'selected',
                  'Export Selected ECU',
                  FluentIcons.processing,
                  'Files for selected ECU only',
                  isDark,
                ),
                _buildExportModeOption(
                  'byECU',
                  'Export by ECU Filter',
                  FluentIcons.filter,
                  'Choose specific ECU',
                  isDark,
                ),

                // ECU Selector when byECU mode
                if (_exportMode == 'byECU') ...[
                  const SizedBox(height: 12),
                  ComboBox<String>(
                    value: _selectedExportECU,
                    placeholder: const Text('Select ECU...'),
                    isExpanded: true,
                    items: ecus
                        .map(
                          (e) => ComboBoxItem(
                            value: e.name,
                            child: Row(
                              children: [
                                Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${e.files.length} files)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AQColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedExportECU = v),
                  ),
                ],

                const SizedBox(height: 20),

                // Structure Options
                Text(
                  'Output Structure',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AQColors.textPrimary
                        : AQColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Checkbox(
                  checked: _preserveStructure,
                  onChanged: (v) =>
                      setState(() => _preserveStructure = v ?? true),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preserve PSDZ folder structure',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AQColors.textPrimary
                              : AQColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        'Maintains swe/cafd/swfl hierarchy',
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark
                              ? AQColors.textMuted
                              : AQColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Container(
                  height: 1,
                  color: AQColors.primaryBlue.withOpacity(0.2),
                ),
                const SizedBox(height: 24),

                // Export Buttons
                _buildExportButton(
                  icon: FluentIcons.download,
                  label: 'Start Export',
                  color: AQColors.success,
                  onPressed: psdz.currentTALFile == null
                      ? null
                      : () => _executeExport(psdz),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        onPressed: psdz.currentTALFile == null
                            ? null
                            : () => _exportECUListTxt(psdz),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.text_document, size: 12),
                            SizedBox(width: 6),
                            Text('TXT List', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Button(
                        onPressed: psdz.currentTALFile == null
                            ? null
                            : () => _exportECUListCsv(psdz),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.table, size: 12),
                            SizedBox(width: 6),
                            Text('CSV List', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right Panel - Preview
        Expanded(
          child: psdz.currentTALFile == null
              ? GlassCard(
                  title: '📋 Export Preview',
                  icon: FluentIcons.preview,
                  expand: true,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.download,
                          size: 64,
                          color: isDark
                              ? AQColors.textSecondary
                              : AQColors.lightTextSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Load a TAL/SVT file to export',
                          style: TextStyle(
                            color: isDark
                                ? AQColors.textSecondary
                                : AQColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : GlassCard(
                  title: '📋 Export Preview - ${_getExportModeName()}',
                  icon: FluentIcons.preview,
                  expand: true,
                  child: _buildExportPreview(psdz),
                ),
        ),
      ],
    );
  }

  Widget _buildExportModeOption(
    String mode,
    String title,
    IconData icon,
    String description,
    bool isDark,
  ) {
    final isSelected = _exportMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _exportMode = mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? AQColors.accentCyan.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AQColors.accentCyan
                : AQColors.primaryBlue.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AQColors.accentCyan
                  : (isDark
                      ? AQColors.textSecondary
                      : AQColors.lightTextSecondary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AQColors.accentCyan
                          : (isDark
                              ? AQColors.textPrimary
                              : AQColors.lightTextPrimary),
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 9,
                      color:
                          isDark ? AQColors.textMuted : AQColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AQColors.accentCyan : AQColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AQColors.accentCyan,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _getExportModeName() {
    switch (_exportMode) {
      case 'all':
        return 'All Files';
      case 'found':
        return 'Found Only';
      case 'selected':
        return 'Selected ECU';
      case 'byECU':
        return _selectedExportECU ?? 'By ECU';
      default:
        return 'Export';
    }
  }

  Future<void> _executeExport(PSDZService psdz) async {
    if (_exportPath.isEmpty) {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        setState(() => _exportPath = result);
      } else {
        return;
      }
    }

    switch (_exportMode) {
      case 'all':
        await _exportAllECUs(psdz);
        break;
      case 'found':
        await _exportFoundOnly(psdz);
        break;
      case 'selected':
        await _exportSelectedECU(psdz);
        break;
      case 'byECU':
        if (_selectedExportECU != null) {
          await _exportSpecificECU(psdz, _selectedExportECU!);
        }
        break;
    }
  }

  Future<void> _exportSpecificECU(PSDZService psdz, String ecuName) async {
    if (_exportPath.isEmpty) {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        _exportPath = result;
      } else {
        return;
      }
    }

    if (mounted) {
      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(
          title: 'Exporting ECU: $ecuName',
          future: psdz.extractSingleECU(ecuName, _exportPath),
        ),
      );
    }
  }

  Future<void> _exportECUListTxt(PSDZService psdz) async {
    final tal = psdz.currentTALFile;
    if (tal == null) return;

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ECU List',
      fileName: 'ecu_list_${tal.filename.replaceAll('.', '_')}.txt',
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('BMW PSDZ ECU List Export');
      buffer.writeln('Generated by BMW PSDZ Ultimate Tool');
      buffer.writeln('Developer: M A coding | Website: https://bmw-az.info/');
      buffer.writeln('=' * 60);
      buffer.writeln('File: ${tal.filename}');
      buffer.writeln('Type: ${tal.type.name.toUpperCase()}');
      buffer.writeln('Total ECUs: ${tal.ecus.length}');
      buffer.writeln('=' * 60);
      buffer.writeln();

      for (var ecu in tal.ecus) {
        final foundCount =
            ecu.files.where((f) => f.status == FileStatus.found).length;
        buffer.writeln(
          '${ecu.name} (${ecu.addressHex}) - $foundCount/${ecu.files.length} files',
        );
        for (var f in ecu.files) {
          final status = f.status == FileStatus.found ? '✓' : '✗';
          buffer.writeln('  $status ${f.processClass}:${f.id} ${f.version}');
          if (f.path != null && f.path!.isNotEmpty) {
            buffer.writeln('    → ${f.path}');
          }
        }
        buffer.writeln();
      }

      await File(result).writeAsString(buffer.toString());
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: Text('ECU list exported to $result'),
            severity: InfoBarSeverity.success,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    }
  }

  Future<void> _exportECUListCsv(PSDZService psdz) async {
    final tal = psdz.currentTALFile;
    if (tal == null) return;

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ECU List (CSV)',
      fileName: 'ecu_list_${tal.filename.replaceAll('.', '_')}.csv',
    );

    if (result != null) {
      final buffer = StringBuffer();
      buffer.writeln('ECU,Address,FileType,FileID,Version,Status,Path');

      for (var ecu in tal.ecus) {
        for (var f in ecu.files) {
          final status = f.status == FileStatus.found ? 'Found' : 'Missing';
          buffer.writeln(
            '${ecu.name},${ecu.addressHex},${f.processClass},${f.id},${f.version},$status,${f.path ?? ""}',
          );
        }
      }

      await File(result).writeAsString(buffer.toString());
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: Text('CSV exported to $result'),
            severity: InfoBarSeverity.success,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    }
  }

  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final isDisabled = onPressed == null;

    return Container(
      decoration: BoxDecoration(
        gradient: isDisabled
            ? null
            : LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isDisabled
            ? (isDark
                ? AQColors.textMuted.withOpacity(0.3)
                : AQColors.lightTextMuted)
            : null,
        borderRadius: BorderRadius.circular(6),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: FilledButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          foregroundColor: WidgetStateProperty.all(
            isDisabled
                ? (isDark ? AQColors.textMuted : AQColors.lightTextMuted)
                : Colors.white,
          ),
        ),
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isDisabled
                    ? (isDark ? AQColors.textMuted : AQColors.lightTextMuted)
                    : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDisabled
                      ? (isDark ? AQColors.textMuted : AQColors.lightTextMuted)
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportPreview(PSDZService psdz) {
    final ecus = psdz.currentTALFile?.ecus ?? [];
    int totalFiles = 0;
    int foundFiles = 0;

    for (var ecu in ecus) {
      totalFiles += ecu.files.length;
      foundFiles += ecu.files.where((f) => f.status == FileStatus.found).length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AQColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              _buildStatItem('ECUs', '${ecus.length}', AQColors.primaryBlue),
              const SizedBox(width: 24),
              _buildStatItem('Total Files', '$totalFiles', Colors.orange),
              const SizedBox(width: 24),
              _buildStatItem('Found', '$foundFiles', AQColors.success),
              const SizedBox(width: 24),
              _buildStatItem(
                'Missing',
                '${totalFiles - foundFiles}',
                AQColors.secondaryRed,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: ecus.length,
            itemBuilder: (context, index) {
              final ecu = ecus[index];
              final found =
                  ecu.files.where((f) => f.status == FileStatus.found).length;

              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        ecu.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      ecu.addressHex,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$found/${ecu.files.length} files',
                      style: const TextStyle(fontSize: 11),
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

  Widget _buildStatItem(String label, String value, Color color) {
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

  Future<void> _matchAllVersionsForService(PSDZService psdz) async {
    // Match all versions
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: const Text('Version Matching'),
        content: const Text('Matching versions to PSDZ data...'),
        severity: InfoBarSeverity.info,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
  }

  void _resetVersions(PSDZService psdz) {
    // Reset all matched versions - reload the file
    final tal = psdz.currentTALFile;
    if (tal == null) return;

    // Reload the file to reset
    if (tal.path.isNotEmpty) {
      psdz.loadTALFile(tal.path);
    }
    // Refresh UI
    setState(() {});

    if (mounted) {
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: const Text('Versions Reset'),
          content: const Text('File reloaded with original versions.'),
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
          severity: InfoBarSeverity.info,
        ),
      );
    }
  }

  Future<void> _exportSelectedECU(PSDZService psdz) async {
    if (_selectedECUIndex == null) {
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: const Text('No ECU Selected'),
          content: const Text('Please select an ECU to export.'),
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
          severity: InfoBarSeverity.warning,
        ),
      );
      return;
    }

    if (_exportPath.isEmpty) {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        _exportPath = result;
      } else {
        return;
      }
    }

    final tal = psdz.currentTALFile;
    if (tal == null) return;

    final ecu = tal.ecus[_selectedECUIndex!];

    if (mounted) {
      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(
          title: 'Exporting ECU: ${ecu.name}',
          future: psdz.exportTALWithFilter(
            outputPath: _exportPath,
            filterMode: 'byECU',
            selectedECUName: ecu.name,
            preserveStructure: _preserveStructure,
          ),
        ),
      );
    }
  }

  Future<void> _exportAllECUs(PSDZService psdz) async {
    if (_exportPath.isEmpty) {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        _exportPath = result;
      } else {
        return;
      }
    }

    if (mounted) {
      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(
          title: 'Exporting All ECUs',
          future: psdz.exportTALWithFilter(
            outputPath: _exportPath,
            filterMode: 'all',
            preserveStructure: _preserveStructure,
          ),
        ),
      );
    }
  }

  Future<void> _exportFoundOnly(PSDZService psdz) async {
    if (_exportPath.isEmpty) {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        _exportPath = result;
      } else {
        return;
      }
    }

    if (mounted) {
      await showFluentDialog(
        context: context,
        builder: (ctx) => ProgressDialog(
          title: 'Exporting Found Files Only',
          future: psdz.exportTALWithFilter(
            outputPath: _exportPath,
            filterMode: 'found',
            preserveStructure: _preserveStructure,
          ),
        ),
      );
    }
  }

  Widget _buildFileSelection(PSDZService psdz) {
    return GlassCard(
      title: '📄 SVT-TAL File Selection',
      icon: FluentIcons.document,
      child: Row(
        children: [
          const Text(
            'Active File:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextBox(
              placeholder: 'Select TAL or SVT XML file...',
              controller: TextEditingController(
                text: psdz.currentTALFile?.path ?? '',
              ),
              readOnly: true,
            ),
          ),
          const SizedBox(width: 8),
          Button(
            child: const Text('Browse'),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                dialogTitle: 'Select TAL/SVT File',
                type: FileType.custom,
                allowedExtensions: ['xml'],
              );
              if (result != null && result.files.single.path != null) {
                await psdz.loadTALFile(result.files.single.path!);
                setState(() => _selectedECUIndex = null);
              }
            },
          ),
          const SizedBox(width: 8),
          FilledButton(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(FluentIcons.open_file, size: 14),
                SizedBox(width: 6),
                Text('Load'),
              ],
            ),
            onPressed: psdz.currentTALFile == null
                ? null
                : () => psdz.loadTALFile(psdz.currentTALFile!.path),
          ),
          const SizedBox(width: 16),

          // File info
          if (psdz.currentTALFile != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AQColors.primaryBlue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                psdz.currentTALFile!.type.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'VIN: ${psdz.currentTALFile!.vin ?? "N/A"}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 12),
            Text(
              'ECUs: ${psdz.currentTALFile!.ecuCount}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // Removed _buildLibrarySection as it is now a full tab

  Widget _buildECUList(PSDZService psdz) {
    final ecus = psdz.currentTALFile?.ecus ?? [];

    return GlassCard(
      title: '🔧 ECUs in File (${ecus.length})',
      icon: FluentIcons.processing,
      expand: true,
      child: ecus.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.document_search,
                    size: 48,
                    color: AQColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text('Load a TAL/SVT file to view ECUs'),
                ],
              ),
            )
          : ListView.builder(
              itemCount: ecus.length,
              itemBuilder: (context, index) {
                final ecu = ecus[index];
                final isSelected = _selectedECUIndex == index;

                return ListTile.selectable(
                  selected: isSelected,
                  onPressed: () => setState(() => _selectedECUIndex = index),
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AQColors.primaryBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        ecu.addressHex,
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: 'Consolas',
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    ecu.name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${ecu.files.length} files',
                    style: TextStyle(
                      fontSize: 11,
                      color: AQColors.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(FluentIcons.edit, size: 14),
                        onPressed: () => _showEditECUDialog(ecu, index),
                      ),
                      IconButton(
                        icon: Icon(
                          FluentIcons.delete,
                          size: 14,
                          color: AQColors.secondaryRed,
                        ),
                        onPressed: () => _confirmDeleteECU(index),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFileEditor(PSDZService psdz) {
    final ecus = psdz.currentTALFile?.ecus ?? [];
    final selectedECU =
        _selectedECUIndex != null && _selectedECUIndex! < ecus.length
            ? ecus[_selectedECUIndex!]
            : null;

    if (selectedECU == null) {
      return GlassCard(
        title: '📝 ECU Files Editor',
        icon: FluentIcons.edit_create,
        expand: true,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.edit, size: 48, color: AQColors.textSecondary),
              const SizedBox(height: 16),
              const Text('Select an ECU to edit its files'),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      title: '📝 ${selectedECU.name} Files (${selectedECU.files.length})',
      icon: FluentIcons.edit_create,
      expand: true,
      child: Column(
        children: [
          // Toolbar
          Row(
            children: [
              Button(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(FluentIcons.add, size: 14),
                    SizedBox(width: 6),
                    Text('Add File'),
                  ],
                ),
                onPressed: () => _showAddFileDialog(selectedECU),
              ),
              const SizedBox(width: 8),
              Button(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(FluentIcons.sync, size: 14),
                    SizedBox(width: 6),
                    Text('Auto-Match Versions'),
                  ],
                ),
                onPressed: () => _autoMatchVersions(selectedECU),
              ),
              const Spacer(),
              Button(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(FluentIcons.check_mark, size: 14),
                    SizedBox(width: 6),
                    Text('Check Files'),
                  ],
                ),
                onPressed: () => _checkFiles(selectedECU),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Files list
          Expanded(
            child: ListView.builder(
              itemCount: selectedECU.files.length,
              itemBuilder: (context, index) {
                final file = selectedECU.files[index];
                final foundPath = psdz.findFile(
                  file.processClass,
                  file.id,
                  file.mainVersion,
                  file.subVersion,
                  file.patchVersion,
                );
                final isFound = foundPath != null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AQColors.textSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isFound
                          ? AQColors.success.withOpacity(0.3)
                          : AQColors.secondaryRed.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Status
                      Icon(
                        isFound ? FluentIcons.check_mark : FluentIcons.warning,
                        size: 16,
                        color: isFound ? AQColors.success : AQColors.warning,
                      ),
                      const SizedBox(width: 12),

                      // Type
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
                          file.processClass,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // ID
                      SizedBox(
                        width: 80,
                        child: Text(
                          file.id,
                          style: const TextStyle(fontFamily: 'Consolas'),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Version (editable)
                      SizedBox(
                        width: 120,
                        child: TextBox(
                          controller: TextEditingController(text: file.version),
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 12,
                          ),
                          onSubmitted: (value) =>
                              _updateFileVersion(index, value),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Found path
                      Expanded(
                        child: Text(
                          isFound ? foundPath : 'Not found in PSDZ data',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isFound ? Colors.white : AQColors.secondaryRed,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Actions
                      IconButton(
                        icon: Icon(
                          FluentIcons.delete,
                          size: 14,
                          color: AQColors.secondaryRed,
                        ),
                        onPressed: () => _deleteFile(index),
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
    final hasChanges = psdz.currentTALFile?.isModified ?? false;

    return Row(
      children: [
        // Status
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).cardColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                if (hasChanges)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AQColors.warning,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'Modified',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    psdz.statusMessage,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Actions
        Button(
          child: const Text('📥 Extract All ECUs'),
          onPressed: psdz.currentTALFile == null
              ? null
              : () async {
                  final result = await FilePicker.platform.getDirectoryPath();
                  if (result != null) {
                    // Extract all ECUs
                  }
                },
        ),
        const SizedBox(width: 8),
        Button(
          child: const Text('💾 Save As...'),
          onPressed: psdz.currentTALFile == null ? null : () => _saveAs(),
        ),
        const SizedBox(width: 8),
        FilledButton(
          child: const Text('💾 Save'),
          onPressed: hasChanges ? () => _save() : null,
        ),
      ],
    );
  }

  // Dialog methods
  void _showEditECUDialog(ECU ecu, int index) {
    final nameController = TextEditingController(text: ecu.name);
    final addressController = TextEditingController(text: ecu.addressHex);

    showFluentDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text('Edit ECU: ${ecu.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoLabel(
              label: 'Name',
              child: TextBox(controller: nameController),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'Diagnostic Address',
              child: TextBox(controller: addressController),
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            child: const Text('Save'),
            onPressed: () {
              // Save changes
              final newName = nameController.text;
              final newAddressHex = addressController.text;
              final newAddress =
                  int.tryParse(newAddressHex.replaceAll('0x', ''), radix: 16) ??
                      ecu.address;

              final newEcu = ecu.copyWith(name: newName, address: newAddress);
              context.read<PSDZService>().updateECU(index, newEcu);

              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteECU(int index) {
    showFluentDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Delete ECU?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AQColors.secondaryRed),
            ),
            child: const Text('Delete'),
            onPressed: () {
              context.read<PSDZService>().deleteECU(index);
              Navigator.pop(ctx);
              setState(() {
                if (_selectedECUIndex == index) _selectedECUIndex = null;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showAddFileDialog(ECU ecu) {
    showFluentDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Add File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoLabel(
              label: 'Process Class',
              child: ComboBox<String>(
                value: 'SWFL',
                items: [
                  'BTLD',
                  'SWFL',
                  'SWFK',
                  'CAFD',
                  'IBAD',
                ].map((s) => ComboBoxItem(value: s, child: Text(s))).toList(),
                onChanged: (v) {},
              ),
            ),
            const SizedBox(height: 12),
            InfoLabel(label: 'ID', child: TextBox()),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'Version (main.sub.patch)',
              child: TextBox(placeholder: '000.000.000'),
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            child: const Text('Add'),
            onPressed: () {
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _autoMatchVersions(ECU ecu) {
    // Auto-match file versions based on available files in PSDZ
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: const Text('Auto-Match'),
        content: const Text('Matching versions to available PSDZ files...'),
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
        severity: InfoBarSeverity.info,
      ),
    );
  }

  void _checkFiles(ECU ecu) {
    final psdz = context.read<PSDZService>();
    int found = 0, missing = 0;

    for (var file in ecu.files) {
      final path = psdz.findFile(
        file.processClass,
        file.id,
        file.mainVersion,
        file.subVersion,
        file.patchVersion,
      );
      if (path != null) {
        found++;
      } else {
        missing++;
      }
    }

    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: const Text('File Check Result'),
        content: Text('Found: $found | Missing: $missing'),
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
        severity:
            missing > 0 ? InfoBarSeverity.warning : InfoBarSeverity.success,
      ),
    );
  }

  void _updateFileVersion(int index, String version) {
    // Note: ECUFile properties are immutable
    // Display info that direct editing is not supported in current model
    if (mounted) {
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: const Text('Version Update'),
          content: Text('Version would be updated to: $version'),
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
          severity: InfoBarSeverity.info,
        ),
      );
    }
  }

  void _deleteFile(int index) {
    // Note: ECU files list is immutable in current model
    // Display confirmation only
    if (mounted) {
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: const Text('Delete File'),
          content: const Text('File deletion requires saving to a new file.'),
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
          severity: InfoBarSeverity.warning,
        ),
      );
    }
  }

  void _saveAs() async {
    final psdz = context.read<PSDZService>();
    final tal = psdz.currentTALFile;
    if (tal == null) return;

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save TAL/SVT File',
      fileName: tal.filename,
      allowedExtensions: ['xml'],
      type: FileType.custom,
    );

    if (result != null) {
      try {
        await psdz.saveTALFile(result);
        if (mounted) {
          displayInfoBar(
            context,
            builder: (ctx, close) => InfoBar(
              title: const Text('File Saved'),
              content: Text('Saved to: $result'),
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
              severity: InfoBarSeverity.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (ctx, close) => InfoBar(
              title: const Text('Save Failed'),
              content: Text('Error: $e'),
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
              severity: InfoBarSeverity.error,
            ),
          );
        }
      }
    }
  }

  void _save() {
    final psdz = context.read<PSDZService>();
    final tal = psdz.currentTALFile;
    if (tal == null || tal.path.isEmpty) {
      _saveAs();
      return;
    }

    psdz.saveTALFile(tal.path).then((_) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: const Text('File Saved'),
            content: Text('Saved: ${tal.filename}'),
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
            severity: InfoBarSeverity.success,
          ),
        );
      }
    }).catchError((e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: const Text('Save Failed'),
            content: Text('Error: $e'),
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    });
  }
}
