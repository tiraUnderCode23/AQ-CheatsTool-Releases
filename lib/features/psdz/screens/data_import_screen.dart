// BMW PSDZ Ultimate Tool - Data Manager Screen
// Developer: M A coding | Website: https://bmw-az.info/
// Signature: AQ///bimmer
// Professional Data Import/Export with full PSDZ Analyzer capabilities

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../theme/aq_theme.dart';
import '../services/psdz_service.dart';
import '../models/ecu.dart';
import '../widgets/progress_dialog.dart';

class DataImportScreen extends StatefulWidget {
  const DataImportScreen({super.key});

  @override
  State<DataImportScreen> createState() => _DataImportScreenState();
}

class _DataImportScreenState extends State<DataImportScreen> {
  // Tab control
  int _currentTab = 0; // 0 = Import, 1 = Export

  // Import state
  String _importMode = 'all';
  String? _selectedImportSeries;
  String? _selectedImportIStep;
  String? _selectedImportECU;
  String? _importSourcePath;
  bool _isImporting = false;
  String _importStatus = '';
  List<_ImportItem> _importItems = [];

  // Export state
  String _exportMode = 'selected';
  String? _selectedExportSeries;
  String? _selectedExportIStep;
  bool _preserveStructure = true;
  String? _lastExportPath;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Consumer<PSDZService>(
      builder: (context, psdz, _) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AQColors.darkBackground : AQColors.lightBackground,
          ),
          child: Column(
            children: [
              _buildHeader(isDark, psdz),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _currentTab == 0
                      ? _buildImportPanel(isDark, psdz)
                      : _buildExportPanel(isDark, psdz),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, PSDZService psdz) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AQColors.surfaceBackground
            : AQColors.lightSurfaceBackground,
        border: Border(
          bottom: BorderSide(color: AQColors.primaryBlue.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Title with icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AQColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(FluentIcons.sync, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Manager',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AQColors.textPrimary
                      : AQColors.lightTextPrimary,
                ),
              ),
              Text(
                'Import & Export PSDZ Data',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AQColors.textSecondary
                      : AQColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Tab buttons
          _buildTabButton('Import', FluentIcons.download, 0, isDark),
          const SizedBox(width: 8),
          _buildTabButton('Export', FluentIcons.upload, 1, isDark),
          const Spacer(),
          // M Stripes
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(
              gradient: AQColors.mStripesGradient,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 16),
          // Library status
          _buildLibraryStatus(isDark, psdz),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int tab, bool isDark) {
    final isSelected = _currentTab == tab;

    return GestureDetector(
      onTap: () => setState(() => _currentTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AQColors.primaryGradient : null,
          color: isSelected
              ? null
              : (isDark
                    ? AQColors.textSecondary.withOpacity(0.1)
                    : AQColors.lightSurfaceBackground),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AQColors.primaryBlue.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AQColors.textSecondary
                        : AQColors.lightTextSecondary),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AQColors.textSecondary
                          : AQColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryStatus(bool isDark, PSDZService psdz) {
    final hasLibrary = psdz.psdzPath != null && psdz.psdzPath!.isNotEmpty;
    final stats = psdz.getStatistics();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasLibrary
            ? AQColors.success.withOpacity(0.1)
            : AQColors.secondaryRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasLibrary
              ? AQColors.success.withOpacity(0.3)
              : AQColors.secondaryRed.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasLibrary ? FluentIcons.check_mark : FluentIcons.warning,
            size: 14,
            color: hasLibrary ? AQColors.success : AQColors.secondaryRed,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasLibrary ? 'Library Loaded' : 'No Library',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: hasLibrary ? AQColors.success : AQColors.secondaryRed,
                ),
              ),
              if (hasLibrary)
                Text(
                  '${stats['totalECUs'] ?? 0} ECUs | ${stats['totalFiles'] ?? 0} Files',
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark
                        ? AQColors.textMuted
                        : AQColors.lightTextMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== IMPORT PANEL ====================

  Widget _buildImportPanel(bool isDark, PSDZService psdz) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left - Import Options
        SizedBox(width: 320, child: _buildImportOptions(isDark, psdz)),
        const SizedBox(width: 16),
        // Right - Import Preview
        Expanded(child: _buildImportPreview(isDark, psdz)),
      ],
    );
  }

  Widget _buildImportOptions(bool isDark, PSDZService psdz) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AQColors.surfaceBackground.withOpacity(0.5)
            : AQColors.lightSurfaceBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AQColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AQColors.primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  FluentIcons.settings,
                  size: 14,
                  color: AQColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Import Options',
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
          const SizedBox(height: 16),

          // Source Path
          Text(
            'Source Path',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AQColors.textSecondary
                  : AQColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AQColors.darkBackground : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AQColors.primaryBlue.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    _importSourcePath ?? 'No folder selected',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Consolas',
                      color: _importSourcePath != null
                          ? (isDark
                                ? AQColors.textPrimary
                                : AQColors.lightTextPrimary)
                          : (isDark
                                ? AQColors.textMuted
                                : AQColors.lightTextMuted),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: _selectImportSource,
                child: const Text('Browse'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Import Mode
          Text(
            'Import Mode',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AQColors.textSecondary
                  : AQColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildImportModeRadio(
            'all',
            'Import All',
            FluentIcons.select_all,
            isDark,
          ),
          _buildImportModeRadio('series', 'By Series', FluentIcons.car, isDark),
          _buildImportModeRadio(
            'istep',
            'By I-Step',
            FluentIcons.timeline,
            isDark,
          ),
          _buildImportModeRadio(
            'ecu',
            'By ECU',
            FluentIcons.processing,
            isDark,
          ),
          const SizedBox(height: 16),

          // Conditional selectors
          if (_importMode == 'series') ...[
            Text(
              'Select Series',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ComboBox<String>(
                value: _selectedImportSeries,
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
                onChanged: (v) => setState(() => _selectedImportSeries = v),
              ),
            ),
          ],
          if (_importMode == 'istep') ...[
            Text(
              'Select I-Step',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ComboBox<String>(
                value: _selectedImportIStep,
                isExpanded: true,
                placeholder: const Text('Choose I-Step...'),
                items: psdz.iSteps
                    .map(
                      (i) => ComboBoxItem(value: i.name, child: Text(i.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedImportIStep = v),
              ),
            ),
          ],
          if (_importMode == 'ecu') ...[
            Text(
              'Select ECU',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ComboBox<String>(
                value: _selectedImportECU,
                isExpanded: true,
                placeholder: const Text('Choose ECU...'),
                items: psdz.ecus
                    .map(
                      (e) => ComboBoxItem(
                        value: e.name,
                        child: Text('${e.name} (${e.addressHex})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedImportECU = v),
              ),
            ),
          ],

          const Spacer(),

          // Import Button
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: AQColors.primaryGradient,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: AQColors.primaryBlue.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                ),
                onPressed: _isImporting || _importSourcePath == null
                    ? null
                    : () => _startImport(psdz),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isImporting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    else
                      const Icon(FluentIcons.download, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      _isImporting ? 'Importing...' : 'Start Import',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportModeRadio(
    String value,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _importMode == value;

    return GestureDetector(
      onTap: () => setState(() => _importMode = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AQColors.primaryBlue.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? AQColors.primaryBlue
                : AQColors.primaryBlue.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AQColors.primaryBlue
                  : (isDark
                        ? AQColors.textSecondary
                        : AQColors.lightTextSecondary),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AQColors.primaryBlue
                    : (isDark
                          ? AQColors.textPrimary
                          : AQColors.lightTextPrimary),
              ),
            ),
            const Spacer(),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AQColors.primaryBlue : AQColors.textMuted,
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
                          color: AQColors.primaryBlue,
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

  Widget _buildImportPreview(bool isDark, PSDZService psdz) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AQColors.surfaceBackground.withOpacity(0.5)
            : AQColors.lightSurfaceBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AQColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AQColors.accentCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  FluentIcons.preview,
                  size: 14,
                  color: AQColors.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Import Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AQColors.textPrimary
                      : AQColors.lightTextPrimary,
                ),
              ),
              const Spacer(),
              if (_importItems.isNotEmpty) ...[
                _buildBadge(
                  '${_importItems.length}',
                  'Items',
                  AQColors.primaryBlue,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildBadge(
                  _formatSize(
                    _importItems.fold<int>(0, (sum, i) => sum + i.size),
                  ),
                  null,
                  AQColors.accentCyan,
                  isDark,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Status bar
          if (_importStatus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AQColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AQColors.primaryBlue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  if (_isImporting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      FluentIcons.info,
                      size: 14,
                      color: AQColors.primaryBlue,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _importStatus,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AQColors.textSecondary
                            : AQColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Items list
          Expanded(
            child: _importItems.isEmpty
                ? _buildEmptyPreview(isDark)
                : ListView.builder(
                    itemCount: _importItems.length,
                    itemBuilder: (context, index) {
                      final item = _importItems[index];
                      return _buildImportItem(item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPreview(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.folder_open,
            size: 48,
            color: isDark ? AQColors.textMuted : AQColors.lightTextMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Select a source folder to preview files',
            style: TextStyle(
              color: isDark ? AQColors.textMuted : AQColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportItem(_ImportItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AQColors.textSecondary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getTypeColor(item.type).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getTypeColor(item.type),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              item.type,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Consolas',
                color: isDark
                    ? AQColors.textPrimary
                    : AQColors.lightTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Size
          Text(
            _formatSize(item.size),
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AQColors.textMuted : AQColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'SWE':
        return AQColors.primaryBlue;
      case 'CAFD':
        return AQColors.accentCyan;
      case 'SWFL':
        return AQColors.success;
      case 'TAL':
        return AQColors.mBlue;
      case 'SVT':
        return AQColors.mRed;
      case 'FA':
        return AQColors.mBlue;
      default:
        return AQColors.textSecondary;
    }
  }

  // ==================== EXPORT PANEL ====================

  Widget _buildExportPanel(bool isDark, PSDZService psdz) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left - Export Options
        SizedBox(width: 320, child: _buildExportOptions(isDark, psdz)),
        const SizedBox(width: 16),
        // Right - Export Preview (ECU/Files list)
        Expanded(child: _buildExportPreview(isDark, psdz)),
      ],
    );
  }

  Widget _buildExportOptions(bool isDark, PSDZService psdz) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AQColors.surfaceBackground.withOpacity(0.5)
            : AQColors.lightSurfaceBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AQColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AQColors.accentCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  FluentIcons.upload,
                  size: 14,
                  color: AQColors.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Export Options',
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
          const SizedBox(height: 16),

          // Export Mode
          Text(
            'Export Mode',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AQColors.textSecondary
                  : AQColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildExportModeRadio(
            'selected',
            'Export Selected ECU',
            FluentIcons.processing,
            isDark,
          ),
          _buildExportModeRadio(
            'series',
            'Export by Series',
            FluentIcons.car,
            isDark,
          ),
          _buildExportModeRadio(
            'istep',
            'Export by I-Step',
            FluentIcons.timeline,
            isDark,
          ),
          _buildExportModeRadio(
            'all',
            'Export All Files',
            FluentIcons.select_all,
            isDark,
          ),
          const SizedBox(height: 16),

          // Conditional selectors
          if (_exportMode == 'series') ...[
            Text(
              'Select Series',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
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
          if (_exportMode == 'istep') ...[
            Text(
              'Select I-Step',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
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
          const SizedBox(height: 16),

          // Preserve structure option
          Checkbox(
            checked: _preserveStructure,
            onChanged: (v) => setState(() => _preserveStructure = v ?? true),
            content: Text(
              'Preserve folder structure',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Container(height: 1, color: AQColors.primaryBlue.withOpacity(0.2)),
          const SizedBox(height: 16),

          // Export List buttons
          Text(
            'Export Lists',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AQColors.textSecondary
                  : AQColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Button(
                  onPressed: psdz.ecus.isEmpty
                      ? null
                      : () => _exportEcuListTxt(psdz),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FluentIcons.paste, size: 12),
                      SizedBox(width: 6),
                      Text('TXT List', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Button(
                  onPressed: psdz.ecus.isEmpty
                      ? null
                      : () => _exportEcuListCsv(psdz),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FluentIcons.table, size: 12),
                      SizedBox(width: 6),
                      Text('CSV List', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Main Export Button
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: psdz.ecus.isEmpty ? null : AQColors.accentGradient,
                color: psdz.ecus.isEmpty
                    ? (isDark
                          ? AQColors.textMuted.withOpacity(0.3)
                          : AQColors.lightTextMuted)
                    : null,
                borderRadius: BorderRadius.circular(6),
                boxShadow: psdz.ecus.isEmpty
                    ? null
                    : [
                        BoxShadow(
                          color: AQColors.accentCyan.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                  foregroundColor: WidgetStateProperty.all(
                    psdz.ecus.isEmpty
                        ? (isDark
                              ? AQColors.textMuted
                              : AQColors.lightTextMuted)
                        : Colors.white,
                  ),
                ),
                onPressed: psdz.ecus.isEmpty ? null : () => _startExport(psdz),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _preserveStructure
                            ? FluentIcons.folder
                            : FluentIcons.upload,
                        size: 14,
                        color: psdz.ecus.isEmpty
                            ? (isDark
                                  ? AQColors.textMuted
                                  : AQColors.lightTextMuted)
                            : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _preserveStructure
                            ? 'Export Structured'
                            : 'Start Export',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: psdz.ecus.isEmpty
                              ? (isDark
                                    ? AQColors.textMuted
                                    : AQColors.lightTextMuted)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportModeRadio(
    String value,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _exportMode == value;

    return GestureDetector(
      onTap: () => setState(() => _exportMode = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AQColors.accentCyan.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? AQColors.accentCyan
                : AQColors.primaryBlue.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AQColors.accentCyan
                  : (isDark
                        ? AQColors.textSecondary
                        : AQColors.lightTextSecondary),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AQColors.accentCyan
                    : (isDark
                          ? AQColors.textPrimary
                          : AQColors.lightTextPrimary),
              ),
            ),
            const Spacer(),
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

  Widget _buildExportPreview(bool isDark, PSDZService psdz) {
    final stats = psdz.getStatistics();
    final foundCount = stats['foundFiles'] ?? 0;
    final missingCount = stats['missingFiles'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AQColors.surfaceBackground.withOpacity(0.5)
            : AQColors.lightSurfaceBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AQColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with search
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AQColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  FluentIcons.library,
                  size: 14,
                  color: AQColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Available Data',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AQColors.textPrimary
                      : AQColors.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 16),
              _buildBadge('$foundCount', 'Found', AQColors.success, isDark),
              const SizedBox(width: 8),
              _buildBadge(
                '$missingCount',
                'Missing',
                AQColors.secondaryRed,
                isDark,
              ),
              const Spacer(),
              // Search box
              SizedBox(
                width: 200,
                height: 28,
                child: TextBox(
                  controller: _searchController,
                  placeholder: 'Search ECU...',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(FluentIcons.search, size: 12),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ECU List
          Expanded(
            child: psdz.ecus.isEmpty
                ? _buildNoDataMessage(isDark)
                : _buildEcuList(isDark, psdz),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataMessage(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.database,
            size: 48,
            color: isDark ? AQColors.textMuted : AQColors.lightTextMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No data loaded',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AQColors.textMuted : AQColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Load data from PSDZ Analyzer first',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AQColors.textMuted : AQColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcuList(bool isDark, PSDZService psdz) {
    final filteredEcus = psdz.ecus.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.name.toLowerCase().contains(_searchQuery) ||
          e.addressHex.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView.builder(
      itemCount: filteredEcus.length,
      itemBuilder: (context, index) {
        final ecu = filteredEcus[index];
        return _buildEcuCard(ecu, isDark, psdz);
      },
    );
  }

  Widget _buildEcuCard(ECU ecu, bool isDark, PSDZService psdz) {
    final foundFiles = ecu.files
        .where((f) => f.status == FileStatus.found)
        .length;
    final totalFiles = ecu.files.length;
    final isSelected = psdz.selectedECU == ecu.name;

    return GestureDetector(
      onTap: () => psdz.selectECU(ecu.name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AQColors.primaryBlue.withOpacity(0.15)
              : (isDark
                    ? AQColors.textSecondary.withOpacity(0.1)
                    : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AQColors.primaryBlue
                : AQColors.primaryBlue.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // ECU Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isSelected ? AQColors.primaryGradient : null,
                color: isSelected
                    ? null
                    : AQColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                FluentIcons.processing,
                size: 18,
                color: isSelected ? Colors.white : AQColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            // ECU Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ecu.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AQColors.textPrimary
                              : AQColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AQColors.accentCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          ecu.addressHex,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'Consolas',
                            color: AQColors.accentCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        FluentIcons.document,
                        size: 10,
                        color: isDark
                            ? AQColors.textMuted
                            : AQColors.lightTextMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$foundFiles / $totalFiles files found',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AQColors.textSecondary
                              : AQColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Progress
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    totalFiles > 0
                        ? '${(foundFiles / totalFiles * 100).toInt()}%'
                        : '0%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: foundFiles == totalFiles
                          ? AQColors.success
                          : (foundFiles > 0
                                ? AQColors.primaryBlue
                                : AQColors.secondaryRed),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 60,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AQColors.textMuted.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: totalFiles > 0
                            ? foundFiles / totalFiles
                            : 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: foundFiles == totalFiles
                                ? AQColors.success
                                : AQColors.primaryBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String value, String? label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isDark
                    ? AQColors.textSecondary
                    : AQColors.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            value,
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

  // ==================== ACTIONS ====================

  Future<void> _selectImportSource() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Source Folder',
    );

    if (result != null) {
      setState(() {
        _importSourcePath = result;
        _importStatus = 'Scanning folder...';
        _importItems = [];
      });

      // Scan in background
      await _scanImportSource(result);
    }
  }

  Future<void> _scanImportSource(String path) async {
    setState(() => _isImporting = true);

    try {
      final items = await compute(_scanFolderIsolate, path);
      setState(() {
        _importItems = items;
        _importStatus = 'Found ${items.length} files';
        _isImporting = false;
      });
    } catch (e) {
      setState(() {
        _importStatus = 'Error: $e';
        _isImporting = false;
      });
    }
  }

  static List<_ImportItem> _scanFolderIsolate(String path) {
    final items = <_ImportItem>[];
    final dir = Directory(path);

    if (!dir.existsSync()) return items;

    final validExtensions = {
      '.prg',
      '.bin',
      '.btl',
      '.sgbmid',
      '.caf',
      '.xml',
      '.json',
      '.tal',
      '.svt',
      '.fa',
    };
    final skipFolders = {
      'node_modules',
      '.git',
      'build',
      'windows',
      'docs',
      'temp',
      'cache',
      'logs',
      '__pycache__',
    };

    void scanDir(Directory d, int depth) {
      if (depth > 10) return;

      try {
        for (var entity in d.listSync()) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (validExtensions.contains(ext)) {
              final name = p.basename(entity.path);
              final type = _getFileType(name, ext);
              items.add(
                _ImportItem(
                  name: name,
                  path: entity.path,
                  type: type,
                  size: entity.lengthSync(),
                ),
              );
            }
          } else if (entity is Directory) {
            final dirName = p.basename(entity.path).toLowerCase();
            if (!skipFolders.contains(dirName)) {
              scanDir(entity, depth + 1);
            }
          }
        }
      } catch (_) {}
    }

    scanDir(dir, 0);
    return items;
  }

  static String _getFileType(String name, String ext) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('swe_')) return 'SWE';
    if (nameLower.contains('cafd_')) return 'CAFD';
    if (nameLower.contains('swfl_')) return 'SWFL';
    if (nameLower.contains('btld_')) return 'BTLD';
    if (ext == '.tal') return 'TAL';
    if (ext == '.svt') return 'SVT';
    if (ext == '.fa') return 'FA';
    if (ext == '.xml') return 'XML';
    return 'FILE';
  }

  Future<void> _startImport(PSDZService psdz) async {
    if (_importSourcePath == null || _importItems.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importStatus = 'Importing files...';
    });

    try {
      // Get target path
      final target = psdz.psdzPath ?? _importSourcePath!;

      int imported = 0;
      for (var item in _importItems) {
        // Copy file based on mode
        if (_shouldImportItem(item, psdz)) {
          final destPath = p.join(target, item.name);
          await File(item.path).copy(destPath);
          imported++;
        }
      }

      setState(() {
        _isImporting = false;
        _importStatus = 'Imported $imported files successfully';
      });

      // Refresh library
      if (psdz.psdzPath != null) {
        await psdz.scanLibrary();
      }

      if (mounted) {
        _showInfoBar('Imported $imported files', InfoBarSeverity.success);
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _importStatus = 'Import error: $e';
      });

      if (mounted) {
        _showInfoBar('Import failed: $e', InfoBarSeverity.error);
      }
    }
  }

  bool _shouldImportItem(_ImportItem item, PSDZService psdz) {
    switch (_importMode) {
      case 'series':
        if (_selectedImportSeries == null) return false;
        return item.name.toLowerCase().contains(
          _selectedImportSeries!.toLowerCase(),
        );
      case 'istep':
        if (_selectedImportIStep == null) return false;
        return item.name.toLowerCase().contains(
          _selectedImportIStep!.toLowerCase(),
        );
      case 'ecu':
        if (_selectedImportECU == null) return false;
        return item.name.toLowerCase().contains(
          _selectedImportECU!.toLowerCase(),
        );
      default:
        return true;
    }
  }

  Future<void> _startExport(PSDZService psdz) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Export Folder',
    );

    if (result == null || !mounted) return;

    switch (_exportMode) {
      case 'selected':
        await _exportSelectedECU(psdz, result);
        break;
      case 'series':
        await _exportBySeries(psdz, result);
        break;
      case 'istep':
        await _exportByIStep(psdz, result);
        break;
      case 'all':
        await _exportAllFiles(psdz, result);
        break;
    }
  }

  Future<void> _exportSelectedECU(PSDZService psdz, String outputPath) async {
    if (psdz.selectedECU == null) {
      _showInfoBar('Please select an ECU first', InfoBarSeverity.warning);
      return;
    }

    final filesToExtract = psdz.files
        .where((f) => f.status == FileStatus.found)
        .toList();

    if (filesToExtract.isEmpty) {
      _showInfoBar(
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
                '$outputPath/${psdz.selectedECU}',
              )
            : psdz.extractFiles(
                filesToExtract,
                '$outputPath/${psdz.selectedECU}',
              ),
      ),
    );
  }

  Future<void> _exportBySeries(PSDZService psdz, String outputPath) async {
    if (_selectedExportSeries == null) {
      _showInfoBar('Please select a series first', InfoBarSeverity.warning);
      return;
    }

    await showFluentDialog(
      context: context,
      builder: (ctx) => ProgressDialog(
        title: 'Extracting $_selectedExportSeries files',
        future: psdz.exportBySeries(
          _selectedExportSeries!,
          '$outputPath/$_selectedExportSeries',
          preserveStructure: _preserveStructure,
        ),
      ),
    );
  }

  Future<void> _exportByIStep(PSDZService psdz, String outputPath) async {
    if (_selectedExportIStep == null) {
      _showInfoBar('Please select an I-Step first', InfoBarSeverity.warning);
      return;
    }

    await showFluentDialog(
      context: context,
      builder: (ctx) => ProgressDialog(
        title: 'Extracting $_selectedExportIStep files',
        future: psdz.exportByIStep(
          _selectedExportIStep!,
          '$outputPath/$_selectedExportIStep',
          preserveStructure: _preserveStructure,
        ),
      ),
    );
  }

  Future<void> _exportAllFiles(PSDZService psdz, String outputPath) async {
    final filesToExtract = await psdz.collectFoundFilesForCurrentIStep();

    if (filesToExtract.isEmpty) {
      _showInfoBar('No files to export', InfoBarSeverity.warning);
      return;
    }

    await showFluentDialog(
      context: context,
      builder: (ctx) => ProgressDialog(
        title: 'Extracting All Files',
        future: _preserveStructure
            ? psdz.extractFilesWithStructure(filesToExtract, outputPath)
            : psdz.extractFiles(filesToExtract, outputPath),
      ),
    );
  }

  Future<void> _exportEcuListTxt(PSDZService psdz) async {
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
      if (mounted) {
        _showInfoBar('ECU list exported to $result', InfoBarSeverity.success);
      }
    }
  }

  Future<void> _exportEcuListCsv(PSDZService psdz) async {
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
      if (mounted) {
        _showInfoBar('CSV exported to $result', InfoBarSeverity.success);
      }
    }
  }

  void _showInfoBar(String message, InfoBarSeverity severity) {
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// Import item model
class _ImportItem {
  final String name;
  final String path;
  final String type;
  final int size;

  const _ImportItem({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
  });
}
