import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path_lib;

import '../../core/providers/zgw_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/resource_decryptor.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/terminal_widget.dart';

class MguUnlockTab extends StatefulWidget {
  const MguUnlockTab({super.key});

  @override
  State<MguUnlockTab> createState() => _MguUnlockTabState();
}

class _MguUnlockTabState extends State<MguUnlockTab>
    with SingleTickerProviderStateMixin {
  String _selectedMguType = 'MGU';
  String _selectedOperation = 'Unlock';
  bool _isProcessing = false;
  int _currentStep = 0;

  // ECU Info state
  Map<String, String> _ecuInfo = {};
  bool _isReadingEcuInfo = false;
  bool _isWritingVin = false;
  String? _originalVin;

  // Custom VIN input controller
  final TextEditingController _vinInputController = TextEditingController();
  final TextEditingController _customCommandController =
      TextEditingController();

  final List<String> _mguTypes = ['MGU', 'MGU1', 'MGU2', 'MGU3'];
  final List<String> _operations = [
    'Unlock',
    'Lock',
    'Test Connection',
    'SSH Connect',
    'Direct Tool32',
    'Full Unlock Sequence',
  ];

  // MGU Data matching Python implementation
  final Map<String, Map<String, dynamic>> _mguData = {
    'MGU': {
      'vin': 'WBACV61000LJ72069',
      'command': 'c:/MGU;0x03',
      'file': 'MGU',
      'color': const Color(0xFFFF6B35),
      'description': 'Main MGU Configuration',
      'job': 'steuern_provisioning_data',
    },
    'MGU1': {
      'vin': 'WBSGV0C0XNCG84455',
      'command': 'c:/MGU1;0x03',
      'file': 'MGU1',
      'color': const Color(0xFF2E86AB),
      'description': 'Alternative MGU1 Setup',
      'job': 'steuern_provisioning_data',
    },
    'MGU2': {
      'vin': 'WBA7K510307K42189',
      'command': 'c:/MGU2;0x03',
      'file': 'MGU2',
      'color': const Color(0xFFA23B72),
      'description': 'MGU2 Extended Configuration',
      'job': 'steuern_provisioning_data',
    },
    'MGU3': {
      'vin': 'WBA5R1109KAK30355',
      'command': 'c:/MGU3;0x03',
      'file': 'MGU3',
      'color': const Color(0xFFF18F01),
      'description': 'MGU3 Special Configuration',
      'job': 'steuern_provisioning_data',
    },
  };

  // Guide steps with images - EXACT match to Python version
  final List<Map<String, dynamic>> _guideSteps = [
    {
      'step': 1,
      'title': '🔌 Connect via E-Sys',
      'description': '🔌 Connect your car via E-Sys\n\n🔧 FSC Extended',
      'image': 'assets/images/mgu1.jpg',
      'isWarning': false,
    },
    {
      'step': 2,
      'title': '🎯 Diagnostic Address',
      'description': '🎯 Diagnostic Address (hex): 0x63\n\n✅ Click Identify',
      'image': 'assets/images/mgu2.jpg',
      'isWarning': false,
    },
    {
      'step': 3,
      'title': '📝 WriteDataByIdentifierVIN',
      'description':
          '📝 WriteDataByIdentifierVIN\n\n📋 Paste unlocked VIN\n\n✅ Click OK',
      'image': 'assets/images/mgu3.jpg',
      'isWarning': false,
    },
    {
      'step': 4,
      'title': '🔄 Reboot ECU',
      'description': '🔄 Reboot ECU\n\n⚠️ This step is critical!',
      'image': 'assets/images/mgu4.jpg',
      'isWarning': true,
      'hasRebootButton': true,
    },
    {
      'step': 5,
      'title': '🛠️ Open Tool32',
      'description': '🛠️ Open Tool32\n\n📂 Select HU_MGU.PRG',
      'image': 'assets/images/mgu6.jpg',
      'isWarning': false,
    },
    {
      'step': 6,
      'title': '⚙️ Select Job',
      'description': '⚙️ Select Job:\nsteuern_provisioning_data',
      'image': 'assets/images/mgu5.jpg',
      'isWarning': false,
    },
    {
      'step': 7,
      'title': '📝 Paste Command',
      'description': '📝 Paste cmd command selected in Arguments\n\n⚡ Press F5',
      'image': null,
      'isWarning': true,
    },
    {
      'step': 8,
      'title': '🔌 Reconnect E-Sys',
      'description': '🔌 Connect your car via E-Sys\n\n🔧 FSC Extended',
      'image': 'assets/images/mgu1.jpg',
      'isWarning': false,
    },
    {
      'step': 9,
      'title': '🎯 Identify Again',
      'description': '🎯 Diagnostic Address (hex): 0x63\n\n✅ Click Identify',
      'image': 'assets/images/mgu2.jpg',
      'isWarning': false,
    },
    {
      'step': 10,
      'title': '📝 Restore ORIGINAL VIN',
      'description':
          '📝 WriteDataByIdentifierVIN\n\n📋 Paste your ORIGINAL VIN\n\n✅ Click OK',
      'image': 'assets/images/mgu3.jpg',
      'isWarning': true,
    },
    {
      'step': 11,
      'title': '😴 Sleep Car',
      'description': '😴 Sleep car 5 minutes\n\n⏰ WAIT - DO NOT DISTURB!',
      'image': null,
      'isWarning': true,
    },
  ];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vinInputController.dispose();
    _customCommandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final padding = isCompact ? 16.0 : 24.0;

        // Calculate tab content height based on available space
        final headerHeight = isCompact ? 80.0 : 100.0;
        final tabBarHeight = 60.0;
        final spacing = 40.0;
        final availableHeight = constraints.maxHeight -
            headerHeight -
            tabBarHeight -
            spacing -
            (padding * 2);
        final tabContentHeight =
            availableHeight > 400 ? availableHeight : 400.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(isCompact),

              SizedBox(height: isCompact ? 16 : 24),

              // Tab Bar
              _buildTabBar(),

              const SizedBox(height: 16),

              // Tab Content - Flexible height based on screen
              SizedBox(
                height: tabContentHeight,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMainControlsTab(),
                    _buildDirectUdsTab(),
                    _buildGuideTab(),
                  ],
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
          padding: EdgeInsets.all(isCompact ? 8 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AQColors.accent, AQColors.accent.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.lock_open_rounded,
            color: Colors.black,
            size: isCompact ? 22 : 28,
          ),
        ),
        SizedBox(width: isCompact ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MGU Unlock Tool',
                style: TextStyle(
                  fontSize: isCompact ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (!isCompact)
                Text(
                  'Unlock BMW MGU Head Unit for coding and customization',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        // Quick Actions - Hide labels on compact
        Row(
          children: [
            _buildQuickActionButton(
              isCompact ? '' : 'Video Tutorial',
              Icons.play_circle_outline_rounded,
              () => _openVideoTutorial(),
            ),
            const SizedBox(width: 8),
            _buildQuickActionButton(
              isCompact ? '' : 'Open Putty',
              Icons.terminal_rounded,
              () => _openPutty(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: label.isNotEmpty
          ? Text(label, style: const TextStyle(fontSize: 12))
          : const SizedBox.shrink(),
      style: TextButton.styleFrom(
        foregroundColor: AQColors.accent,
        backgroundColor: AQColors.accent.withOpacity(0.1),
        padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? 8 : 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AQColors.accent,
        indicatorWeight: 3,
        labelColor: AQColors.accent,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        tabs: const [
          Tab(
            icon: Icon(Icons.settings_rounded),
            text: 'Main Controls',
          ),
          Tab(
            icon: Icon(Icons.terminal_rounded),
            text: 'Direct UDS / Tool32',
          ),
          Tab(
            icon: Icon(Icons.menu_book_rounded),
            text: 'Visual Guide',
          ),
        ],
      ),
    );
  }

  Widget _buildMainControlsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Controls
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildZgwDiscoveryCard(),
                        const SizedBox(height: 16),
                        _buildEcuInfoCard(),
                        const SizedBox(height: 16),
                        _buildMguOperationsCard(),
                        const SizedBox(height: 16),
                        _buildQuickCommandsCard(),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right side - Terminal
                  Expanded(
                    flex: 1,
                    child: _buildTerminalCard(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ECU Info Card - Shows connected ECU information
  Widget _buildEcuInfoCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_rounded,
                    color: Colors.cyan,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ECU Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_isReadingEcuInfo)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed:
                          zgw.isConnected ? () => _readEcuInfo(zgw) : null,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Read Info'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyan,
                        side: BorderSide(color: Colors.cyan.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              if (!zgw.isConnected)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_rounded,
                          size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connect to car to read ECU information',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_ecuInfo.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Click "Read Info" to fetch ECU data',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: _ecuInfo.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '${entry.key}:',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: entry.value));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${entry.key} copied!'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Icon(Icons.copy,
                                  size: 14,
                                  color: Colors.cyan.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Store original VIN when available
              if (_ecuInfo.containsKey('VIN') && _originalVin == null) ...[
                Builder(builder: (context) {
                  // Store the original VIN
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_originalVin == null && _ecuInfo.containsKey('VIN')) {
                      setState(() {
                        _originalVin = _ecuInfo['VIN'];
                      });
                    }
                  });
                  return const SizedBox.shrink();
                }),
              ],

              const SizedBox(height: 12),

              // Write VIN Section
              if (zgw.isConnected) ...[
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Write VIN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _vinInputController,
                        maxLength: 17,
                        decoration: InputDecoration(
                          hintText: 'Enter 17-character VIN',
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed:
                          _isWritingVin ? null : () => _writeCustomVin(zgw),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: _isWritingVin
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Write'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quick VIN buttons for MGU types
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _mguTypes.map((type) {
                    final mguVin = _mguData[type]!['vin'] as String;
                    return OutlinedButton(
                      onPressed: () {
                        _vinInputController.text = mguVin;
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _mguData[type]!['color'] as Color,
                        side: BorderSide(
                            color: (_mguData[type]!['color'] as Color)
                                .withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      child: Text('$type VIN',
                          style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                ),
                if (_originalVin != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _vinInputController.text = _originalVin!,
                    icon: const Icon(Icons.restore, size: 14),
                    label: Text('Restore Original: $_originalVin',
                        style: const TextStyle(fontSize: 10)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: BorderSide(color: Colors.green.withOpacity(0.5)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  /// Read ECU Info
  Future<void> _readEcuInfo(ZGWProvider zgw) async {
    setState(() => _isReadingEcuInfo = true);

    try {
      zgw.addLog('📖 Reading ECU information...', 'blue');
      final info = await zgw.readEcuInfo();

      setState(() {
        _ecuInfo = info;
        if (info.containsKey('VIN') && _originalVin == null) {
          _originalVin = info['VIN'];
        }
      });

      zgw.addLog('✅ ECU info read: ${info.length} parameters', 'green');
    } catch (e) {
      zgw.addLog('❌ Failed to read ECU info: $e', 'red');
    } finally {
      setState(() => _isReadingEcuInfo = false);
    }
  }

  /// Write custom VIN
  Future<void> _writeCustomVin(ZGWProvider zgw) async {
    final vin = _vinInputController.text.trim().toUpperCase();

    if (vin.length != 17) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('VIN must be exactly 17 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirm VIN Write', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to write this VIN?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                vin,
                style: const TextStyle(
                  color: Colors.orange,
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_originalVin != null) ...[
              const SizedBox(height: 12),
              Text(
                'Original VIN: $_originalVin',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Write VIN'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isWritingVin = true);

    try {
      zgw.addLog('✏️ Writing VIN: $vin', 'blue');
      final result = await zgw.writeVin(vin);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ VIN written: $vin'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh ECU info
        await _readEcuInfo(zgw);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['error'] ?? 'VIN write failed'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      zgw.addLog('❌ VIN write error: $e', 'red');
    } finally {
      setState(() => _isWritingVin = false);
    }
  }

  /// Build Direct UDS / Tool32 Tab
  Widget _buildDirectUdsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left - UDS Commands Config
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildUdsJobExecutionCard(),
                        const SizedBox(height: 16),
                        _buildDirectTool32Card(),
                        const SizedBox(height: 16),
                        _buildMguProvisioningCard(),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right - Terminal
                  Expanded(
                    child: _buildTerminalCard(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideTab() {
    return Column(
      children: [
        // Top Warning Banner (Yellow background, Red text)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.yellow,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.yellow.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                '⚠️ IMPORTANT: Follow these steps exactly as shown! ⚠️',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Step indicator
        _buildStepIndicator(),
        const SizedBox(height: 16),

        // Guide content
        Expanded(
          child: _buildGuideContent(),
        ),

        const SizedBox(height: 12),

        // Bottom Warning Banner (Red background, White text)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_rounded, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                '⚠️ CRITICAL: Make sure to use ORIGINAL VIN in Step 10! ⚠️',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.error_rounded, color: Colors.white, size: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZgwDiscoveryCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AQColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ZGW Discovery',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  _buildConnectionStatus(zgw),
                ],
              ),

              const SizedBox(height: 16),

              // Connection info
              if (zgw.isConnected) ...[
                _buildInfoRow(
                    'IP Address', zgw.zgwIp.isEmpty ? 'Unknown' : zgw.zgwIp),
                _buildInfoRow('VIN', zgw.vin.isEmpty ? 'Unknown' : zgw.vin),
                if (zgw.huIp.isNotEmpty)
                  _buildInfoRow('Head Unit IP', zgw.huIp),
                const SizedBox(height: 12),

                // Copy buttons
                Row(
                  children: [
                    _buildCopyButton('Copy IP', zgw.zgwIp),
                    const SizedBox(width: 8),
                    _buildCopyButton('Copy VIN', zgw.vin),
                    if (zgw.huIp.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _buildCopyButton('Copy HU IP', zgw.huIp),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Found cars
              if (zgw.foundCars.isNotEmpty) ...[
                Text(
                  'Found Cars (${zgw.foundCars.length}):',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    itemCount: zgw.foundCars.length,
                    itemBuilder: (context, index) {
                      return _buildCarItem(zgw.foundCars[index]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      text: zgw.isSearching ? 'Searching...' : 'Search ZGW',
                      icon: Icons.search_rounded,
                      isLoading: zgw.isSearching,
                      onPressed: () => zgw.startSearch(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (zgw.isConnected)
                    Expanded(
                      child: GlassButton(
                        text: 'Disconnect',
                        icon: Icons.link_off_rounded,
                        isOutlined: true,
                        onPressed: () => zgw.disconnect(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus(ZGWProvider zgw) {
    if (zgw.isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF27C93F).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27C93F).withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF27C93F),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Connected',
              style: TextStyle(
                color: Color(0xFF27C93F),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (zgw.isSearching) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Searching...',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCopyButton(String label, String value) {
    return OutlinedButton.icon(
      onPressed: value.isNotEmpty
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied!'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AQColors.accent,
                ),
              );
            }
          : null,
      icon: const Icon(Icons.copy_rounded, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AQColors.accent,
        side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AQColors.accent,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarItem(Map<String, dynamic> car) {
    final zgw = context.read<ZGWProvider>();
    final isSelected = zgw.zgwIp == car['ip'];

    return GestureDetector(
      onTap: () => zgw.selectCar(car),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AQColors.accent.withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AQColors.accent : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.directions_car_rounded,
              color:
                  isSelected ? AQColors.accent : Colors.white.withOpacity(0.5),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car['vin'] ?? 'Unknown VIN',
                    style: TextStyle(
                      color: isSelected ? AQColors.accent : Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    car['ip'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AQColors.accent,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMguOperationsCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        final mguInfo = _mguData[_selectedMguType]!;

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.build_rounded,
                    color: AQColors.secondary,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'MGU Operations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // MGU Type selector
              Row(
                children: [
                  Text(
                    'MGU Type:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: _mguTypes.map((type) {
                        final isSelected = _selectedMguType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          selectedColor: AQColors.accent.withOpacity(0.3),
                          backgroundColor: Colors.white.withOpacity(0.05),
                          labelStyle: TextStyle(
                            color: isSelected ? AQColors.accent : Colors.white,
                            fontSize: 12,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedMguType = type);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // MGU Info with copy buttons
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (mguInfo['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (mguInfo['color'] as Color).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // VIN Row with copy
                    Row(
                      children: [
                        Icon(Icons.car_rental,
                            size: 16, color: mguInfo['color'] as Color),
                        const SizedBox(width: 8),
                        Text(
                          'VIN: ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            mguInfo['vin'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildMiniCopyButton('VIN', mguInfo['vin'] as String),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Command Row with copy
                    Row(
                      children: [
                        Icon(Icons.terminal,
                            size: 16, color: mguInfo['color'] as Color),
                        const SizedBox(width: 8),
                        Text(
                          'Command: ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            mguInfo['command'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        _buildMiniCopyButton(
                            'Command', mguInfo['command'] as String),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // File Row with copy
                    Row(
                      children: [
                        Icon(Icons.folder,
                            size: 16, color: mguInfo['color'] as Color),
                        const SizedBox(width: 8),
                        Text(
                          'File: ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            mguInfo['file'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        _buildMiniCopyButton('File', mguInfo['file'] as String),
                        const SizedBox(width: 4),
                        _buildTransferFileButton(
                            mguInfo['file'] as String, zgw),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Operation selector
              Row(
                children: [
                  Text(
                    'Operation:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedOperation,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white),
                      underline: Container(),
                      items: _operations.map((op) {
                        return DropdownMenuItem(value: op, child: Text(op));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedOperation = value);
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Copy Files to C:/ button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _copyMguFilesToC(mguInfo['file'] as String),
                  icon: const Icon(Icons.folder_copy_rounded),
                  label: Text('📁 Copy $_selectedMguType File to C:/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Execute button
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  text: _isProcessing ? 'Processing...' : 'Execute',
                  icon: Icons.play_arrow_rounded,
                  isLoading: _isProcessing,
                  color: AQColors.secondary,
                  onPressed:
                      zgw.isConnected ? () => _executeMguOperation(zgw) : null,
                ),
              ),

              if (!zgw.isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Please connect to a car first',
                    style: TextStyle(
                      color: AQColors.secondary.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniCopyButton(String label, String value) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copied!'),
            duration: const Duration(seconds: 1),
            backgroundColor: AQColors.accent,
          ),
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.copy, size: 14, color: AQColors.accent),
      ),
    );
  }

  Widget _buildTransferFileButton(String fileName, ZGWProvider zgw) {
    return InkWell(
      onTap: zgw.isConnected ? () => _transferMguFile(fileName, zgw) : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: zgw.isConnected
              ? Colors.green.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.upload_file,
          size: 14,
          color: zgw.isConnected ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Future<void> _transferMguFile(String fileName, ZGWProvider zgw) async {
    zgw.addLog('📤 Transferring file: $fileName', 'blue');
    zgw.addLog(
        '🔗 Target: ${zgw.huIp.isNotEmpty ? zgw.huIp : zgw.zgwIp}', 'info');

    // TODO: Implement actual file transfer via SCP
    await Future.delayed(const Duration(milliseconds: 500));
    zgw.addLog('✅ File transfer initiated', 'green');
    zgw.addLog('💡 Use SSH to verify file on MGU', 'orange');
  }

  Future<void> _copyMguFilesToC(String fileName) async {
    final zgw = context.read<ZGWProvider>();

    try {
      zgw.addLog('📁 Copying $fileName to C:/$fileName...', 'blue');

      // Get the source path from ResourceDecryptor (for encrypted builds)
      final attachPath = ResourceDecryptor.attachmentsPath;
      final srcPath = path_lib.join(attachPath, fileName);
      final destPath = 'C:\\$fileName';

      zgw.addLog('📍 Source: $srcPath', 'info');

      // Check if it's a file (MGU files are actually files, not folders)
      final srcFile = File(srcPath);
      final srcDir = Directory(srcPath);

      if (await srcFile.exists()) {
        // It's a file - copy it directly
        zgw.addLog('📄 Detected as file, copying...', 'info');
        await srcFile.copy(destPath);
        zgw.addLog('✅ Successfully copied $fileName to C:\\', 'green');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Successfully copied $fileName to C:/'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      } else if (await srcDir.exists()) {
        // It's a directory - copy it recursively
        zgw.addLog('📁 Detected as folder, copying...', 'info');
        await _copyDirectory(srcDir, Directory(destPath));
        zgw.addLog('✅ Successfully copied $fileName to $destPath', 'green');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Successfully copied $fileName to C:/'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Fallback: try development paths
      zgw.addLog('⚠️ Not found in extracted, trying dev paths...', 'orange');

      final devPaths = [
        path_lib.join(ResourceDecryptor.attachmentsPath, fileName),
        path_lib.join(path_lib.dirname(Platform.resolvedExecutable), 'data',
            'flutter_assets', 'assets', 'attachments', fileName),
      ];

      for (final devPath in devPaths) {
        final devFile = File(devPath);
        if (await devFile.exists()) {
          await devFile.copy(destPath);
          zgw.addLog('✅ Copied from dev path: $devPath', 'green');
          return;
        }
      }

      zgw.addLog('❌ File not found: $fileName', 'red');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $fileName not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      zgw.addLog('❌ Failed to copy $fileName: $e', 'red');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to copy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDir = Directory(
            '${destination.path}/${entity.path.split(Platform.pathSeparator).last}');
        await _copyDirectory(entity, newDir);
      } else if (entity is File) {
        await entity.copy(
            '${destination.path}/${entity.path.split(Platform.pathSeparator).last}');
      }
    }
  }

  Widget _buildQuickCommandsCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.flash_on_rounded,
                    color: Colors.amber,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Quick Commands',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Quick commands grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickCommand(
                      'DEFSESS', 'Default Session', '10 01', zgw),
                  _buildQuickCommand('PROGSESS', 'Prog Session', '10 02', zgw),
                  _buildQuickCommand(
                      'EXTDIAGSESS', 'Ext Diag Session', '10 03', zgw),
                  _buildQuickCommand('ReadVIN', 'Read VIN', '22 F1 90', zgw),
                  _buildQuickCommand('HardReset', 'Hard Reset', '11 01', zgw),
                  _buildQuickCommand('ReadDTC', 'Read DTC', '19 02 0C', zgw),
                  _buildQuickCommand(
                      'ClearDTC', 'Clear DTC', '14 FF FF FF', zgw),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickCommand(
      String name, String label, String command, ZGWProvider zgw) {
    return Tooltip(
      message: 'UDS: $command',
      child: OutlinedButton(
        onPressed: zgw.isConnected
            ? () async {
                zgw.addLog('⚡ Executing $name ($command)', 'blue');
                await zgw.sendUdsCommand(command);
              }
            : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.amber,
          side: BorderSide(color: Colors.amber.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  /// UDS Job Execution Card - Replaces PyDiabas with direct UDS
  Widget _buildUdsJobExecutionCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        final mguInfo = _mguData[_selectedMguType]!;

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.terminal_rounded,
                    color: AQColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'UDS Job Execution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Direct DoIP/UDS',
                      style: TextStyle(color: Colors.blue, fontSize: 10),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ECU Target selection
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.memory_rounded,
                            size: 16, color: AQColors.accent),
                        SizedBox(width: 8),
                        Text(
                          'Target ECU: Head Unit (0x63)',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.folder_rounded,
                            size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(
                          'SGBD: HU_MGU.prg ($_selectedMguType)',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Job Name
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.work_rounded,
                        size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Text('Job: ',
                        style: TextStyle(color: Colors.purple, fontSize: 12)),
                    Expanded(
                      child: Text(
                        mguInfo['job'] as String,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: mguInfo['job'] as String));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Job name copied!'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                      child: Icon(Icons.copy,
                          size: 14, color: Colors.purple.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Arguments
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code_rounded,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Args: ',
                        style: TextStyle(color: Colors.green, fontSize: 12)),
                    Expanded(
                      child: Text(
                        mguInfo['command'] as String,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: mguInfo['command'] as String));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Arguments copied!'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                      child: Icon(Icons.copy,
                          size: 14, color: Colors.green.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Custom Arguments input
              TextField(
                controller: _customCommandController,
                decoration: InputDecoration(
                  hintText: 'Custom arguments (e.g., c:/MGU;0x03)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.terminal,
                      color: Colors.white.withOpacity(0.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'monospace', fontSize: 13),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      text: 'Test Connection',
                      icon: Icons.speed_rounded,
                      onPressed:
                          zgw.isConnected ? () => _testConnection(zgw) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GlassButton(
                      text: 'Execute Job',
                      icon: Icons.play_circle_outline_rounded,
                      color: AQColors.secondary,
                      onPressed: zgw.isConnected
                          ? () => _executeJobWithArgs(zgw)
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Quick Job buttons
              const Text('Quick Jobs:',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildJobButton('IDENT', 'ident', zgw),
                  _buildJobButton('FS_LESEN', 'fs_lesen', zgw),
                  _buildJobButton('FS_LOESCHEN', 'fs_loeschen', zgw),
                  _buildJobButton('STATUS_LESEN', 'status_lesen', zgw),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// MGU Provisioning Card - Full unlock workflow
  Widget _buildMguProvisioningCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        final mguInfo = _mguData[_selectedMguType]!;

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_open_rounded, color: Colors.amber, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'MGU Provisioning (Full Unlock)',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 This will execute the complete unlock sequence:',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Enter Extended Session (10 03)\n'
                      '2. Write MGU VIN: ${mguInfo['vin']}\n'
                      '3. Hard Reset ECU (11 01)\n'
                      '4. Reconnect & Execute Provisioning\n'
                      '5. Restore Original VIN\n'
                      '6. Final Reset',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Original VIN display
              if (_originalVin != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('Original VIN: $_originalVin',
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontFamily: 'monospace')),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                            'Original VIN not captured. Read ECU info first!',
                            style:
                                TextStyle(color: Colors.orange, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed:
                            zgw.isConnected ? () => _readEcuInfo(zgw) : null,
                        child: const Text('Read Now',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Execute Full Unlock button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: zgw.isConnected && _originalVin != null
                      ? () => _executeFullMguUnlockSequence(zgw)
                      : null,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Execute Full Unlock Sequence'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              if (!zgw.isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠️ Connect to ZGW first',
                    style: TextStyle(
                        color: Colors.red.withOpacity(0.7), fontSize: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Test connection
  Future<void> _testConnection(ZGWProvider zgw) async {
    zgw.addLog('🧪 Testing connection...', 'blue');
    await zgw.sendUdsCommand('3E 00');
    zgw.addLog('✅ Connection test completed', 'green');
  }

  Widget _buildJobButton(String label, String jobName, ZGWProvider zgw) {
    return OutlinedButton(
      onPressed: zgw.isConnected
          ? () async {
              zgw.addLog('⚙️ Executing job: $jobName', 'blue');
              final result =
                  await zgw.executeJob(jobName: jobName, argument: '');
              if (result['success'] == true) {
                zgw.addLog('✅ Job completed: $jobName', 'green');
              } else {
                zgw.addLog('❌ Job failed: ${result['error']}', 'red');
              }
            }
          : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.purple,
        side: BorderSide(color: Colors.purple.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  /// Execute job with custom arguments
  Future<void> _executeJobWithArgs(ZGWProvider zgw) async {
    final mguInfo = _mguData[_selectedMguType]!;
    final jobName = mguInfo['job'] as String;
    final defaultArgs = mguInfo['command'] as String;
    final customArgs = _customCommandController.text.trim();

    final args = customArgs.isNotEmpty ? customArgs : defaultArgs;

    zgw.addLog('⚙️ Executing job: $jobName', 'blue');
    zgw.addLog('📝 Arguments: $args', 'info');

    final result = await zgw.executeJob(jobName: jobName, argument: args);

    if (result['success'] == true) {
      zgw.addLog('✅ Job executed successfully', 'green');

      // Show result details
      if (result['details'] != null) {
        final details = result['details'];
        if (details is Map<String, String>) {
          // IDENT result
          for (final entry in details.entries) {
            zgw.addLog('  ${entry.key}: ${entry.value}', 'info');
          }
        } else if (details is Map<String, dynamic> &&
            details['steps'] != null) {
          // Job with steps
          final steps = details['steps'] as List;
          for (final step in steps) {
            zgw.addLog(
                '  ${step['step']}: ${step['result']['success'] ? '✅' : '❌'}',
                'info');
          }
        }
      }
    } else {
      zgw.addLog('❌ Job failed: ${result['error']}', 'red');
    }
  }

  Widget _buildDirectTool32Card() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.terminal_rounded,
                    color: AQColors.accent,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Direct Tool32 Commands',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Custom command input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter UDS command (e.g., 22 F1 90)',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'monospace'),
                      onSubmitted: (value) {
                        if (zgw.isConnected && value.isNotEmpty) {
                          zgw.sendUdsCommand(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: zgw.isConnected ? () {} : null,
                    icon: const Icon(Icons.send_rounded),
                    color: AQColors.accent,
                    style: IconButton.styleFrom(
                      backgroundColor: AQColors.accent.withOpacity(0.1),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Quick commands
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCommandButton('TesterPresent', '3E 00', zgw),
                  _buildCommandButton('Read VIN', '22 F1 90', zgw),
                  _buildCommandButton('Read IP Config', '22 17 2A', zgw),
                  _buildCommandButton('Extended Session', '10 03', zgw),
                  _buildCommandButton('Hard Reset', '11 01', zgw),
                  _buildCommandButton('Read DTC', '19 02 0C', zgw),
                  _buildCommandButton('Clear DTC', '14 FF FF FF', zgw),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommandButton(String label, String command, ZGWProvider zgw) {
    return OutlinedButton(
      onPressed: zgw.isConnected
          ? () async {
              zgw.addLog('📤 Sending: $command', 'blue');
              await zgw.sendUdsCommand(command);
            }
          : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AQColors.accent,
        side: BorderSide(color: AQColors.accent.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildTerminalCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        return GlassCard(
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 450,
            child: TerminalWidget(
              logs: zgw.logMessages,
              onClear: () => zgw.clearLogs(),
              showInput: true,
              onCommand: (cmd) => zgw.sendUdsCommand(cmd),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepIndicator() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _guideSteps.length,
        itemBuilder: (context, index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return GestureDetector(
            onTap: () => setState(() => _currentStep = index),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AQColors.accent.withOpacity(0.2)
                    : isCompleted
                        ? const Color(0xFF27C93F).withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? AQColors.accent
                      : isCompleted
                          ? const Color(0xFF27C93F)
                          : Colors.white.withOpacity(0.1),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AQColors.accent
                          : isCompleted
                              ? const Color(0xFF27C93F)
                              : Colors.white.withOpacity(0.1),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Step ${index + 1}',
                    style: TextStyle(
                      color: isActive
                          ? AQColors.accent
                          : Colors.white.withOpacity(0.7),
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuideContent() {
    final step = _guideSteps[_currentStep];
    final hasImage = step['image'] != null;
    final isWarning = step['isWarning'] == true;
    final hasRebootButton = step['hasRebootButton'] == true;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Image or Step Info
        Expanded(
          flex: 2,
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Image or placeholder
                  Container(
                    height: double.infinity,
                    color: isWarning
                        ? Colors.red.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    child: hasImage
                        ? GestureDetector(
                            onTap: () => _showFullImage(step['image']),
                            child: Image.asset(
                              step['image'],
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildNoImagePlaceholder(step);
                              },
                            ),
                          )
                        : _buildNoImagePlaceholder(step),
                  ),

                  // Step label
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isWarning ? Colors.red : AQColors.accent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: (isWarning ? Colors.red : AQColors.accent)
                                .withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        '📋 STEP ${step['step']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Hover to enlarge hint
                  if (hasImage)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded,
                                size: 14, color: Colors.white70),
                            SizedBox(width: 4),
                            Text(
                              'Click to enlarge',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Right side - Description
        Expanded(
          flex: 1,
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step title
                Text(
                  step['title'],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isWarning ? Colors.red : AQColors.accent,
                  ),
                ),
                const SizedBox(height: 16),

                // Step description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isWarning
                        ? Colors.red.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isWarning
                          ? Colors.red.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    step['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Reboot button for step 4
                if (hasRebootButton) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _rebootHeadUnit(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('🔄 Reboot Head Unit Now!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 Click the button above to reboot the Head Unit directly from here!',
                    style: TextStyle(
                      color: Colors.green[300],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                const Spacer(),

                // Warning notice for critical steps
                if (isWarning && step['step'] == 10) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ CRITICAL: Use ORIGINAL VIN!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Navigation buttons
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: GlassButton(
                          text: 'Previous',
                          icon: Icons.arrow_back_rounded,
                          isOutlined: true,
                          onPressed: () => setState(() => _currentStep--),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 8),
                    if (_currentStep < _guideSteps.length - 1)
                      Expanded(
                        child: GlassButton(
                          text: 'Next',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () => setState(() => _currentStep++),
                        ),
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

  Widget _buildNoImagePlaceholder(Map<String, dynamic> step) {
    final isWarning = step['isWarning'] == true;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isWarning ? Icons.warning_rounded : Icons.info_outline_rounded,
            size: 80,
            color: isWarning
                ? Colors.red.withOpacity(0.5)
                : AQColors.accent.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            step['title'],
            style: TextStyle(
              color: isWarning ? Colors.red : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (isWarning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ IMPORTANT STEP',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dark background
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black.withOpacity(0.8)),
            ),
            // Image
            InteractiveViewer(
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),
            // Close button
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _rebootHeadUnit() {
    final zgw = context.read<ZGWProvider>();
    if (!zgw.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to ZGW first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    zgw.addLog('🔄 Rebooting Head Unit...', 'blue');
    zgw.sendUdsCommand('11 01'); // Hard Reset

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Head Unit reboot command sent!'),
        backgroundColor: AQColors.accent,
      ),
    );
  }

  Future<void> _executeMguOperation(ZGWProvider zgw) async {
    setState(() => _isProcessing = true);

    try {
      final mguInfo = _mguData[_selectedMguType]!;

      switch (_selectedOperation) {
        case 'Unlock':
          zgw.addLog('🔓 Starting MGU Unlock: $_selectedMguType', 'blue');
          zgw.addLog('📋 VIN: ${mguInfo['vin']}', 'info');
          zgw.addLog('⚙️ Command: ${mguInfo['command']}', 'info');

          await zgw.sendProvisioningCommand(
              _selectedMguType, mguInfo['command'] as String);

          zgw.addLog('✅ MGU Unlock command sent successfully', 'green');
          break;

        case 'Lock':
          zgw.addLog('🔒 Starting MGU Lock: $_selectedMguType', 'blue');
          final lockCommand =
              mguInfo['command'].toString().replaceAll('0x03', '0x00');
          await zgw.sendProvisioningCommand(_selectedMguType, lockCommand);
          zgw.addLog('✅ MGU Lock command sent successfully', 'green');
          break;

        case 'Test Connection':
          zgw.addLog('🔄 Testing connection...', 'blue');
          await zgw.sendUdsCommand('3E 00');
          break;

        case 'SSH Connect':
          await _openSshConnection(zgw);
          break;

        case 'Direct Tool32':
          _tabController.animateTo(1);
          break;

        case 'Full Unlock Sequence':
          await _executeFullMguUnlockSequence(zgw);
          break;
      }
    } catch (e) {
      zgw.addLog('❌ Error: $e', 'red');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Execute full MGU unlock sequence
  Future<void> _executeFullMguUnlockSequence(ZGWProvider zgw) async {
    final mguInfo = _mguData[_selectedMguType]!;
    final mguVin = mguInfo['vin'] as String;
    final mguCommand = mguInfo['command'] as String;
    final mguJob = mguInfo['job'] as String;

    // Get original VIN
    String originalVin = _originalVin ?? '';
    if (originalVin.isEmpty && zgw.vin.isNotEmpty) {
      originalVin = zgw.vin;
    }

    if (originalVin.isEmpty) {
      // Try to read VIN first
      zgw.addLog('📖 Reading original VIN...', 'blue');
      final vinResult = await zgw.readVin();
      if (vinResult != null) {
        originalVin = vinResult;
        setState(() => _originalVin = vinResult);
      }
    }

    if (originalVin.isEmpty) {
      // Show dialog to enter original VIN
      final enteredVin = await _showEnterVinDialog(
        title: 'Enter Original VIN',
        message:
            'Could not read VIN automatically. Please enter your car\'s original VIN:',
      );

      if (enteredVin == null || enteredVin.length != 17) {
        zgw.addLog(
            '❌ Original VIN is required for full unlock sequence', 'red');
        return;
      }
      originalVin = enteredVin;
      setState(() => _originalVin = enteredVin);
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Full MGU Unlock Sequence',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will execute the following steps automatically:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              _buildSequenceStepPreview('1', 'Enter Extended Session', '10 03'),
              _buildSequenceStepPreview('2', 'Write MGU VIN', mguVin),
              _buildSequenceStepPreview('3', 'Hard Reset ECU', '11 01'),
              _buildSequenceStepPreview('4', 'Reconnect to ZGW', ''),
              _buildSequenceStepPreview(
                  '5', 'Execute Provisioning', mguCommand),
              _buildSequenceStepPreview(
                  '6', 'Restore Original VIN', originalVin),
              _buildSequenceStepPreview('7', 'Final Reset', '11 01'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ This process will modify your ECU. Make sure you understand what you\'re doing!',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Execute Sequence',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Execute the sequence
    zgw.addLog('🚀 Starting Full MGU Unlock Sequence for $_selectedMguType...',
        'blue');
    zgw.addLog('📋 MGU VIN: $mguVin', 'info');
    zgw.addLog('📋 Original VIN: $originalVin', 'info');
    zgw.addLog('⚙️ Command: $mguCommand', 'info');

    final result = await zgw.executeMguUnlock(
      mguVin: mguVin,
      mguCommand: mguCommand,
      mguJob: mguJob,
      originalVin: originalVin,
    );

    // Show results dialog
    await _showSequenceResultDialog(result);
  }

  Widget _buildSequenceStepPreview(String number, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showEnterVinDialog(
      {required String title, required String message}) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 17,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter 17-character VIN',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style:
                  const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim().toUpperCase()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSequenceResultDialog(Map<String, dynamic> result) async {
    final steps = result['steps'] as List<dynamic>? ?? [];
    final success = result['success'] == true;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              success ? 'Sequence Completed!' : 'Sequence Failed',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...steps.map((step) {
                final stepData = step as Map<String, dynamic>;
                final stepSuccess = stepData['success'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        stepSuccess ? Icons.check_circle : Icons.cancel,
                        color: stepSuccess ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stepData['step']?.toString() ?? 'Unknown step',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                            if (stepData['response'] != null)
                              Text(
                                stepData['response'].toString(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (result['error'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result['error'].toString(),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: success ? Colors.green : Colors.grey,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSshConnection(ZGWProvider zgw) async {
    if (zgw.huIp.isEmpty) {
      zgw.addLog(
          '❌ Head Unit IP not available. Run ZGW discovery first.', 'red');
      return;
    }

    zgw.addLog('🔗 Opening SSH connection to ${zgw.huIp}...', 'blue');
    await _openPutty(ip: zgw.huIp);
  }

  Future<void> _openPutty({String? ip}) async {
    try {
      // Get the executable directory
      String executableDir;
      if (Platform.isWindows) {
        executableDir = Platform.resolvedExecutable;
        executableDir =
            executableDir.substring(0, executableDir.lastIndexOf('\\'));
      } else {
        executableDir = '.';
      }

      // Try multiple possible paths for putty
      final possiblePaths = [
        // ResourceDecryptor path for encrypted builds
        path_lib.join(ResourceDecryptor.attachmentsPath, 'putty', 'putty.exe'),
        // Flutter build output path
        path_lib.join(executableDir, 'data', 'flutter_assets', 'assets',
            'putty', 'putty.exe'),
        // Development path
        path_lib.join(Directory.current.path, 'assets', 'putty', 'putty.exe'),
        // System PuTTY paths
        'C:\\Program Files\\PuTTY\\putty.exe',
        'C:\\Program Files (x86)\\PuTTY\\putty.exe',
      ];

      String? foundPath;
      for (final p in possiblePaths) {
        if (await File(p).exists()) {
          foundPath = p;
          break;
        }
      }

      final zgw = context.read<ZGWProvider>();

      if (foundPath == null) {
        // Try system PATH as last resort
        try {
          if (ip != null && ip.isNotEmpty) {
            await Process.start('putty', ['-ssh', 'root@$ip'],
                runInShell: true);
          } else {
            await Process.start('putty', [], runInShell: true);
          }
          zgw.addLog('✅ Putty opened from system PATH', 'green');
          return;
        } catch (e) {
          zgw.addLog('❌ Putty not found in any path', 'red');
          zgw.addLog('💡 Install PuTTY or add putty.exe to assets/putty folder',
              'orange');
          return;
        }
      }

      zgw.addLog('📁 Found Putty at: $foundPath', 'info');

      if (ip != null && ip.isNotEmpty) {
        await Process.start(foundPath, ['-ssh', 'root@$ip'], runInShell: true);
      } else {
        await Process.start(foundPath, [], runInShell: true);
      }

      zgw.addLog('✅ Putty opened successfully', 'green');
    } catch (e) {
      final zgw = context.read<ZGWProvider>();
      zgw.addLog('❌ Failed to open Putty: $e', 'red');
      zgw.addLog(
          '💡 Make sure putty.exe is in the assets/putty folder or installed on system',
          'orange');
    }
  }

  Future<void> _openVideoTutorial() async {
    const url = 'https://www.youtube.com/watch?v=sXWKJrTaDdY';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      final zgw = context.read<ZGWProvider>();
      zgw.addLog('❌ Failed to open video: $e', 'red');
    }
  }
}
