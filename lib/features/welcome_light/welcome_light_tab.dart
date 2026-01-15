import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class WelcomeLightTab extends StatefulWidget {
  const WelcomeLightTab({super.key});

  @override
  State<WelcomeLightTab> createState() => _WelcomeLightTabState();
}

class _WelcomeLightTabState extends State<WelcomeLightTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedVersion = 'initial';
  // ignore: unused_field
  String _selectedSide = 'links';
  // ignore: unused_field
  String? _selectedModel;
  // ignore: unused_field
  String? _selectedHeadlight;
  // ignore: unused_field
  String? _selectedPattern;
  // ignore: unused_field
  bool _isProcessing = false;
  // ignore: unused_field
  final bool _showModelInfo = false;

  // Sequence data
  List<_SequenceItem> _linksSequence = [];
  List<_SequenceItem> _rechtsSequence = [];

  // HEX Outputs - Staging 1 & 2
  String _linksStaging1 = '';
  String _linksStaging2 = '';
  String _rechtsStaging1 = '';
  String _rechtsStaging2 = '';

  // JSON Data
  Map<String, dynamic> _storedData = {};
  List<String> _availableVersions = [];

  final List<String> _versions = [
    'initial',
    'v2flasher',
    'v3',
    'v4',
    'v5',
    'v6',
    'v7',
    'v8',
    'v9',
    'v10',
    'aqbimmer'
  ];

  // ignore: unused_field
  final List<String> _models = [
    'G20 Pre-LCI',
    'G20 LCI',
    'G80 / G82',
    'G30',
    'G05',
    'G06',
    'G07',
    'F30',
    'F10'
  ];

  // ignore: unused_field
  final List<String> _headlights = [
    'Laser',
    'LED',
    'Adaptive LED',
    'Icon Light'
  ];

  // ignore: unused_field
  final List<_LightPattern> _patterns = [
    _LightPattern(
      id: 'pattern1',
      name: 'Default BMW',
      description: 'Standard BMW welcome light animation',
      icon: Icons.auto_awesome,
    ),
    _LightPattern(
      id: 'pattern2',
      name: 'Laser Show',
      description: 'Dynamic laser beam animation',
      icon: Icons.flash_on_rounded,
    ),
    _LightPattern(
      id: 'pattern3',
      name: 'Sequential',
      description: 'Sequential LED activation',
      icon: Icons.linear_scale_rounded,
    ),
    _LightPattern(
      id: 'pattern4',
      name: 'Fade In/Out',
      description: 'Smooth fade in and out effect',
      icon: Icons.gradient_rounded,
    ),
    _LightPattern(
      id: 'pattern5',
      name: 'Pulse',
      description: 'Pulsing light effect',
      icon: Icons.favorite_rounded,
    ),
    _LightPattern(
      id: 'pattern6',
      name: 'AQ///bimmer Special',
      description: 'AQ///bimmer exclusive pattern',
      icon: Icons.settings_rounded,
    ),
  ];

  // Model Configuration Data
  final Map<String, String> _modelConfigs = {
    'G20 Pre-LCI': '''LM01_Name = 06 = Highbeam2
LM02_Name = 02 = Lowbeam2
LM03_Name = 00
LM04_Name = 03 = Lowbeam3
LM05_Name = 0A = DRL3
LM06_Name = 04 = Lowbeam4
LM07_Name = 02 = Lowbeam2
LM08_Name = 03 = Lowbeam3
LM09_Name = 07 = Highbeam3
LM10_Name = 01 = Lowbeam1
LM11_Name = 09 = DRL2
LM12_Name = 04 = Lowbeam4''',
    'G20 LCI': '''LM01_Name = 00
LM02_Name = 03 = Lowbeam3
LM03_Name = 0A = DRL3
LM04_Name = 07 = Highbeam3
LM05_Name = 04 = Lowbeam4
LM06_Name = 03 = Lowbeam3
LM07_Name = 02 = Lowbeam2
LM08_Name = 06 = Highbeam2
LM09_Name = 03 = Lowbeam3
LM10_Name = 02 = Lowbeam2''',
    'G80 / G82': '''LM01_Name = 00
LM02_Name = 02 = Lowbeam2
LM03_Name = 00
LM04_Name = 02 = Lowbeam2
LM05_Name = 04 = Lowbeam4
LM06_Name = 04 = Lowbeam4
LM07_Name = 06 = Highbeam2
LM08_Name = 03 = Lowbeam3
LM09_Name = 03 = Lowbeam3
LM10_Name = 07 = Highbeam3
LM11_Name = 0A = DRL3
LM12_Name = 09 = DRL2''',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDefaultSequence();
    _loadJsonData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJsonData() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/welcomelight.json');
      final data = json.decode(jsonString);
      setState(() {
        _storedData = data['stored_data'] ?? {};
        _availableVersions = _storedData.keys.toList();
        if (_availableVersions.isNotEmpty) {
          _loadVersionData(_selectedVersion);
        }
      });
    } catch (e) {
      debugPrint('Error loading welcomelight.json: $e');
      // Use default data if JSON not found
    }
  }

  void _loadVersionData(String version) {
    setState(() {
      _selectedVersion = version;
    });

    if (_storedData.containsKey(version)) {
      final versionData = _storedData[version];
      setState(() {
        _linksStaging1 = _formatHexData(versionData['links1'] ?? '');
        _linksStaging2 = _formatHexData(versionData['links2'] ?? '');
        _rechtsStaging1 = _formatHexData(versionData['rechts1'] ?? '');
        _rechtsStaging2 = _formatHexData(versionData['rechts2'] ?? '');
      });
    } else {
      _generateHexOutput();
    }
  }

  String _formatHexData(String hexString) {
    if (hexString.isEmpty) return '';

    // Clean and format hex string
    if (hexString.contains(',')) {
      final hexValues =
          hexString.split(',').map((v) => v.trim().toUpperCase()).toList();
      final lines = <String>[];
      for (var i = 0; i < hexValues.length; i += 16) {
        final lineValues = hexValues.skip(i).take(16).toList();
        lines.add(lineValues.join(', '));
      }
      return lines.join('\n');
    }
    return hexString;
  }

  void _loadDefaultSequence() {
    _linksSequence = [
      _SequenceItem(brightness: '100%', duration: '200ms'),
      _SequenceItem(brightness: '75%', duration: '300ms'),
      _SequenceItem(brightness: '50%', duration: '500ms'),
      _SequenceItem(brightness: '25%', duration: '200ms'),
    ];
    _rechtsSequence = List.from(_linksSequence);
    _generateHexOutput();
  }

  void _generateHexOutput() {
    final linksBuffer = StringBuffer();
    final rechtsBuffer = StringBuffer();

    for (var i = 0; i < _linksSequence.length; i++) {
      final item = _linksSequence[i];
      final brightnessHex = _brightnessToHex(item.brightness);
      final durationHex = _durationToHex(item.duration);
      linksBuffer.write(
          '${brightnessHex.toRadixString(16).padLeft(2, '0').toUpperCase()}, ');
      linksBuffer
          .write(durationHex.toRadixString(16).padLeft(2, '0').toUpperCase());
      if (i < _linksSequence.length - 1) linksBuffer.write(', ');
    }

    for (var i = 0; i < _rechtsSequence.length; i++) {
      final item = _rechtsSequence[i];
      final brightnessHex = _brightnessToHex(item.brightness);
      final durationHex = _durationToHex(item.duration);
      rechtsBuffer.write(
          '${brightnessHex.toRadixString(16).padLeft(2, '0').toUpperCase()}, ');
      rechtsBuffer
          .write(durationHex.toRadixString(16).padLeft(2, '0').toUpperCase());
      if (i < _rechtsSequence.length - 1) rechtsBuffer.write(', ');
    }

    setState(() {
      _linksStaging1 = linksBuffer.toString();
      _rechtsStaging1 = rechtsBuffer.toString();
      // S2 - Extended sequence
      _linksStaging2 = 'Extended: $linksBuffer';
      _rechtsStaging2 = 'Extended: $rechtsBuffer';
    });
  }

  int _brightnessToHex(String brightness) {
    final value = int.parse(brightness.replaceAll('%', ''));
    return (value * 255 ~/ 100);
  }

  int _durationToHex(String duration) {
    final value = int.parse(duration.replaceAll('ms', ''));
    return (value ~/ 10);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final padding = isCompact ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(isCompact),
              SizedBox(height: isCompact ? 12 : 20),

              // Tab bar
              _buildTabBar(isCompact),
              const SizedBox(height: 16),

              // Tab content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVersionAndHexTab(),
                      _buildModelInfoTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 8 : 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AQColors.accent, AQColors.accent.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.lightbulb_rounded,
            color: Colors.black,
            size: isCompact ? 20 : 24,
          ),
        ),
        SizedBox(width: isCompact ? 8 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCompact ? 'Welcome Light' : 'Welcome Light Configuration',
                style: TextStyle(
                  fontSize: isCompact ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (!isCompact)
                const Text(
                  'Welcome Light Editor',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
            ],
          ),
        ),
        // AQ///bimmer Button
        ElevatedButton.icon(
          onPressed: _showAboutDialog,
          icon: const Icon(Icons.info_outline_rounded, size: 18),
          label: Text(isCompact ? 'Info' : 'AQ///bimmer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AQColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('AQ',
                style: TextStyle(
                    color: AQColors.primary, fontWeight: FontWeight.bold)),
            Text('///',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            Text('bimmer',
                style: TextStyle(
                    color: AQColors.secondary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome Light Sequence Editor',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Features:\n• AI-powered sequence generation\n• Manual sequence editor\n• Multiple BMW model support\n• Real-time HEX output\n• Professional AQ branding',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 16),
            Text(
              'Version 2025.1 - Enhanced Edition',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: AQColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isCompact) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicator: BoxDecoration(
          color: AQColors.accent,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        labelStyle: TextStyle(
            fontWeight: FontWeight.bold, fontSize: isCompact ? 11 : 13),
        tabs: [
          Tab(
              text: isCompact ? 'Version & HEX' : 'Version & HEX Output',
              icon: const Icon(Icons.code_rounded, size: 18)),
          Tab(
              text: isCompact ? 'Info' : 'Model Info',
              icon: const Icon(Icons.info_outline_rounded, size: 18)),
        ],
      ),
    );
  }

  /// Combined Version Selector and HEX Output Tab
  Widget _buildVersionAndHexTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version Selector Section
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder_open_rounded,
                        color: AQColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Choose Welcome Light Version',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Version Grid
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _versions.map((version) {
                    final isSelected = _selectedVersion == version;
                    final isAQBimmer = version == 'aqbimmer';

                    return GestureDetector(
                      onTap: () => _loadVersionData(version),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isAQBimmer
                                  ? AQColors.accent
                                  : AQColors.primary)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isAQBimmer
                                ? AQColors.accent
                                : (isSelected
                                    ? AQColors.primary
                                    : Colors.white.withOpacity(0.1)),
                            width: isAQBimmer ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              version == 'initial'
                                  ? '🏠 Initial'
                                  : version == 'v2flasher'
                                      ? '⚡ V2 Flasher'
                                      : version == 'aqbimmer'
                                          ? '🚗 AQ///bimmer'
                                          : '✨ ${version.toUpperCase()}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isAQBimmer
                                        ? AQColors.accent
                                        : Colors.white),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getVersionDescription(version),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white70
                                    : Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Status + Reload Button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22c55e).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF22c55e).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF22c55e), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Selected: ${_selectedVersion.toUpperCase()}',
                              style: const TextStyle(
                                  color: Color(0xFF22c55e), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _loadJsonData(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AQColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // HEX Output Section - Staging 1 Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildHexOutputCard(
                  title: 'FLM2 Links [43] Staging1_Data',
                  hexData: _linksStaging1,
                  color: AQColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHexOutputCard(
                  title: 'FLM2 Rechts [44] Staging1_Data',
                  hexData: _rechtsStaging1,
                  color: AQColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Staging 2 Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildHexOutputCard(
                  title: 'FLM2 Links [43] Staging2_Data',
                  hexData: _linksStaging2,
                  color: AQColors.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHexOutputCard(
                  title: 'FLM2 Rechts [44] Staging2_Data',
                  hexData: _rechtsStaging2,
                  color: AQColors.accent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Copy Actions
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.copy_all_rounded,
                        color: AQColors.accent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Copy HEX Output',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Left side buttons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AQColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Left Side (Links)',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _copyToClipboard(
                                  _linksStaging1, 'Links Staging1'),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Left S1'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AQColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _copyToClipboard(
                                  _linksStaging2, 'Links Staging2'),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Left S2'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AQColors.accent.withOpacity(0.8),
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Right side buttons
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AQColors.secondary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Right Side (Rechts)',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _copyToClipboard(
                                  _rechtsStaging1, 'Rechts Staging1'),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Right S1'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AQColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _copyToClipboard(
                                  _rechtsStaging2, 'Rechts Staging2'),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Right S2'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AQColors.accent.withOpacity(0.8),
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _copyAllData,
                    icon: const Icon(Icons.file_copy_rounded),
                    label: const Text('Copy All Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22c55e),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getVersionDescription(String version) {
    switch (version) {
      case 'initial':
        return 'Original BMW factory';
      case 'v2flasher':
        return 'V2 Flasher enhanced';
      case 'aqbimmer':
        return 'AQ Special Edition';
      default:
        return 'Advanced sequence';
    }
  }

  Widget _buildHexOutputCard({
    required String title,
    required String hexData,
    required Color color,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, color: color, size: 18),
                onPressed: () => _copyToClipboard(hexData, title),
                tooltip: 'Copy',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: SelectableText(
              hexData.isEmpty ? 'No data - Select a version' : hexData,
              style: TextStyle(
                color:
                    hexData.isEmpty ? Colors.white38 : color.withOpacity(0.8),
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String data, String section) {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No data to copy'), backgroundColor: Colors.orange),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: data));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $section copied to clipboard'),
        backgroundColor: const Color(0xFF22c55e),
      ),
    );
  }

  void _copyAllData() {
    final allData = '''
================================================================================
          AQ///bimmer Welcome Light HEX Data Export
================================================================================
Version: ${_selectedVersion.toUpperCase()}
Generated: ${DateTime.now().toString()}
Tool: AQ Cheats Tool v2025.1
================================================================================

[FLM2 Links [43] Staging1_Data]
--------------------------------------------------
$_linksStaging1

[FLM2 Rechts [44] Staging1_Data]
--------------------------------------------------
$_rechtsStaging1

[FLM2 Links [43] Staging2_Data]
--------------------------------------------------
$_linksStaging2

[FLM2 Rechts [44] Staging2_Data]
--------------------------------------------------
$_rechtsStaging2

================================================================================
                    TECHNICAL INFORMATION
================================================================================
• Use NCS Expert or E-Sys for coding
• Backup original coding before applying changes
• Staging1_Data: Primary light sequence
• Staging2_Data: Extended/alternate sequence
================================================================================
''';

    Clipboard.setData(ClipboardData(text: allData));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ All data copied to clipboard'),
        backgroundColor: Color(0xFF22c55e),
      ),
    );
  }

  Widget _buildModelInfoTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explanation
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AQColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Lighting Control Differences Between Models',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'G20 Pre-LCI can only control both daylight running lamps as a single pair, whereas the G80 and G20 LCI can control them individually. This was a side effect of designing the turn signal inside the headlight tubes instead of having a separate turn signal above the tubes.\n\nThis side effect was used to create the cool animations we already know from the European G20 LCI specs. And now the good news: it\'s not hardcoded into the software! The G80/G82 EU-Spec animations are identical and take up most of the data fields.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ID Mappings
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.list_alt_rounded,
                        color: AQColors.accent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'ID Mappings',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    '''00 = n/a       01 = LB1       02 = LB2       03 = LB3
04 = LB4       05 = HB1       06 = HB2       07 = HB3
08 = DRL1      09 = DRL2      10 = DRL3      11 = CL1
12 = CL2       13 = CL3       14 = SML1      15 = SML2
16 = SML3      17 = FRAZ1     18 = ZFL_LSR1   19 = IZ1''',
                    style: TextStyle(
                      color: AQColors.primary.withOpacity(0.8),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Model Configurations
          ..._modelConfigs.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car_rounded,
                              color: AQColors.secondary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            entry.key,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded,
                                color: AQColors.accent, size: 18),
                            onPressed: () =>
                                _copyToClipboard(entry.value, entry.key),
                            tooltip: 'Copy Configuration',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          entry.value,
                          style: TextStyle(
                            color: AQColors.primary.withOpacity(0.8),
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _applyPattern() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome light pattern applied successfully!'),
          backgroundColor: Color(0xFF27C93F),
        ),
      );
    }
  }
}

class _LightPattern {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  _LightPattern({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class _SequenceItem {
  String brightness;
  String duration;

  _SequenceItem({required this.brightness, required this.duration});
}
