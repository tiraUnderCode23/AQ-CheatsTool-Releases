import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path_lib;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/zgw_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/resource_decryptor.dart';
import '../../widgets/glass_card.dart';
import 'aq_image_manager.dart';

/// Image Retrofit Tab - with AQ Image Manager integration
/// Combines Guide, SSH Tools, and Professional Image Swap Tool
class ImageRetrofitTab extends StatefulWidget {
  const ImageRetrofitTab({super.key});

  @override
  State<ImageRetrofitTab> createState() => _ImageRetrofitTabState();
}

class _ImageRetrofitTabState extends State<ImageRetrofitTab> {
  String _selectedUnit = 'NBT1/NBT2EVO';

  // SSH Connection State
  bool _isSSHConnected = false;
  String _sshStatus = 'Disconnected';
  Process? _sshProcess;

  // Terminal Output
  final List<_TerminalLine> _terminalLines = [];
  final ScrollController _terminalScrollController = ScrollController();
  final TextEditingController _commandController = TextEditingController();

  // SSH Credentials
  static const String sshHost = '169.254.199.119';
  static const int sshPort = 22;
  static const String sshUser = 'root';

  // Unit passwords
  final Map<String, String> _unitPasswords = {
    'NBT1/NBT2EVO': 'ts&SK412',
    'EntryNAV': 'Entry0?Evo!',
    'CIC old': 'cic0803',
    'CIC new': 'Hm83stN',
  };

  String get _currentPassword => _unitPasswords[_selectedUnit] ?? 'ts&SK412';

  // Common paths for image replacement
  final Map<String, String> _commonPaths = {
    'M Key Display Path 1':
        '/net/hu-omap/fs/sda0/opt/hmi/ID5/data/ro/bmw/id61/assetDB/Domains/content_preview/PTA_Preview_Guest',
    'M Key Display Path 2':
        '/net/hu-omap/fs/sda0/opt/hmi/ID5/data/ro/bmw/id61/assetDB/Domains/content_preview/cp_fahreprofil_aktivieren',
    'Vehicle Images (ID6)':
        'hu-omap://opt/hmi/ID5/data/ro/bmw/id61/assetDB/Domains/Main/Heroes',
    'Sound Logo Path 1':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/Overlays/bo_logo',
    'Sound Logo Path 2':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/Overlays/bw_logo',
    'ConnectedDrive Logo 1':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/ConnectedDrive/online',
    'ConnectedDrive Logo 2':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/ConnectedDrive/internet',
    'ConnectedDrive Preview 1':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/content_preview_connected_drive',
    'ConnectedDrive Preview 2':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/content_preview_hauptziel',
    'Startup Animation': '/hu-omap/fs/sda0/opt/car/data/eva/images',
  };

  // SSH Quick Commands
  final List<Map<String, String>> _sshCommands = [
    {'name': 'Mount RW', 'cmd': 'mount -uw /fs/sda0'},
    {'name': 'Mount Root RW', 'cmd': 'mount -uw /'},
    {'name': 'List USB', 'cmd': 'ls -l /fs/usb0'},
    {'name': 'Copy SCP', 'cmd': 'cp /fs/usb0/scp /bin/'},
    {'name': 'chmod SCP', 'cmd': 'chmod +x /bin/scp'},
    {'name': 'Mount RO', 'cmd': 'mount -ur /fs/sda0'},
    {'name': 'Reboot', 'cmd': 'reboot'},
  ];

  @override
  void initState() {
    super.initState();
    _addTerminalLine('Image Retrofit Terminal Ready', _TerminalLineType.system);
    _addTerminalLine(
        'Select unit type and use buttons to connect', _TerminalLineType.info);
  }

  @override
  void dispose() {
    _sshProcess?.kill();
    _terminalScrollController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  // ============ Executable Launch Methods ============

  /// Get the base path for the application
  String get _basePath {
    // When running in debug/development
    final exePath = Platform.resolvedExecutable;
    final exeDir = Directory(exePath).parent.path;

    // Check if running from flutter_app folder
    if (exeDir.contains('flutter_app')) {
      return Directory(exeDir).parent.parent.path;
    }
    return exeDir;
  }

  /// Launch an executable from the attachments folder (pluss programs are also in attachments)
  Future<void> _launchPlussProgram(String filename) async {
    try {
      // All programs are now in assets/attachments
      final paths = [
        // ResourceDecryptor path for encrypted builds
        path_lib.join(ResourceDecryptor.attachmentsPath, filename),
        // Flutter build output path
        path_lib.join(_basePath, 'data', 'flutter_assets', 'assets',
            'attachments', filename),
        // Development path
        path_lib.join(
            Directory.current.path, 'assets', 'attachments', filename),
        // Legacy paths
        '$_basePath/assets/attachments/$filename',
        '${Directory.current.path}/assets/attachments/$filename',
      ];

      String? foundPath;
      for (final path in paths) {
        if (await File(path).exists()) {
          foundPath = path;
          break;
        }
      }

      if (foundPath == null) {
        _addTerminalLine('❌ $filename not found in attachments folder',
            _TerminalLineType.error);
        _addTerminalLine('💡 Searched paths:', _TerminalLineType.info);
        for (final path in paths.take(3)) {
          _addTerminalLine('   - $path', _TerminalLineType.info);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('$filename not found. Check assets/attachments folder.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      _addTerminalLine('🚀 Launching $filename...', _TerminalLineType.info);
      _addTerminalLine('📁 Path: $foundPath', _TerminalLineType.info);
      await Process.start(foundPath, [], runInShell: true);
      _addTerminalLine(
          '✅ $filename launched successfully', _TerminalLineType.success);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$filename launched successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _addTerminalLine(
          '❌ Failed to launch $filename: $e', _TerminalLineType.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch $filename: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Launch an executable from the attachments folder
  // ignore: unused_element
  Future<void> _launchAttachment(String filename) async {
    try {
      final paths = [
        // Use ResourceDecryptor for encrypted builds (primary)
        path_lib.join(ResourceDecryptor.attachmentsPath, filename),
        // Flutter build output paths
        '$_basePath/data/flutter_assets/assets/attachments/$filename',
        '$_basePath/attachments/$filename',
        // Development paths
        '${Directory.current.path}/assets/attachments/$filename',
      ];

      String? foundPath;
      for (final path in paths) {
        if (await File(path).exists()) {
          foundPath = path;
          break;
        }
      }

      if (foundPath == null) {
        _addTerminalLine(
            '❌ $filename not found in attachments', _TerminalLineType.error);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$filename not found. Check attachments folder.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      _addTerminalLine('🚀 Launching $filename...', _TerminalLineType.info);
      await Process.start(foundPath, [], runInShell: true);
      _addTerminalLine(
          '✅ $filename launched successfully', _TerminalLineType.success);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$filename launched successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _addTerminalLine(
          '❌ Failed to launch $filename: $e', _TerminalLineType.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch $filename: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show help guide for boot animation
  // ignore: unused_element
  void _showBootAnimationGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Boot Animation Guide', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuideItem(
                  '1️⃣', 'Install ffmpeg.exe in attachments folder'),
              _buildGuideItem('2️⃣', 'Run evoAQ.exe from attachments'),
              _buildGuideItem('3️⃣', 'Select your video file to convert'),
              _buildGuideItem('4️⃣', 'Choose appropriate settings'),
              _buildGuideItem('5️⃣',
                  'Transfer to: /hu-omap/fs/sda0/opt/car/data/eva/images'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Text(
                  '💡 Tip: Use the AQVideo tool for best results with boot animations.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _addTerminalLine(String text, _TerminalLineType type) {
    setState(() {
      _terminalLines.add(_TerminalLine(text: text, type: type));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearTerminal() {
    setState(() {
      _terminalLines.clear();
    });
    _addTerminalLine('Terminal cleared', _TerminalLineType.system);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _addTerminalLine('📋 Copied: $text', _TerminalLineType.info);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 $label copied!'),
        backgroundColor: AQColors.accent,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openPuTTY() async {
    _addTerminalLine('Opening PuTTY...', _TerminalLineType.system);

    try {
      final puttyPaths = [
        // ResourceDecryptor path for encrypted builds
        path_lib.join(ResourceDecryptor.attachmentsPath, 'putty', 'putty.exe'),
        // Flutter build output path
        path_lib.join(_basePath, 'data', 'flutter_assets', 'assets', 'putty',
            'putty.exe'),
        // Development path
        path_lib.join(Directory.current.path, 'assets', 'putty', 'putty.exe'),
        // System PuTTY paths
        'C:\\Program Files\\PuTTY\\putty.exe',
        'C:\\Program Files (x86)\\PuTTY\\putty.exe',
      ];

      String? puttyPath;
      for (final path in puttyPaths) {
        if (await File(path).exists()) {
          puttyPath = path;
          break;
        }
      }

      if (puttyPath != null) {
        _addTerminalLine(
            '📁 Found PuTTY at: $puttyPath', _TerminalLineType.info);
        await Process.start(
            puttyPath,
            [
              '-ssh',
              '$sshUser@$sshHost',
              '-P',
              '$sshPort',
              '-pw',
              _currentPassword,
            ],
            runInShell: true);
        _addTerminalLine(
            'PuTTY opened successfully', _TerminalLineType.success);
      } else {
        // Try system PATH
        _addTerminalLine('Trying system PuTTY...', _TerminalLineType.info);
        await Process.start(
            'putty',
            [
              '-ssh',
              '$sshUser@$sshHost',
              '-P',
              '$sshPort',
              '-pw',
              _currentPassword,
            ],
            runInShell: true);
        _addTerminalLine(
            'PuTTY opened successfully', _TerminalLineType.success);
      }
    } catch (e) {
      _addTerminalLine('Error opening PuTTY: $e', _TerminalLineType.error);
      _addTerminalLine(
          'Please install PuTTY or add putty.exe to assets/putty folder',
          _TerminalLineType.info);
    }
  }

  Future<void> _openWinSCP() async {
    _addTerminalLine('Opening WinSCP...', _TerminalLineType.system);

    try {
      await Process.run('winscp', [
        'sftp://$sshUser:$_currentPassword@$sshHost:$sshPort',
      ]);
      _addTerminalLine('WinSCP opened successfully', _TerminalLineType.success);
    } catch (e) {
      _addTerminalLine('Error opening WinSCP: $e', _TerminalLineType.error);
      _addTerminalLine('Please install WinSCP', _TerminalLineType.info);
    }
  }

  Future<void> _connectSSH() async {
    if (_isSSHConnected) {
      _addTerminalLine('Already connected to SSH', _TerminalLineType.warning);
      return;
    }

    _addTerminalLine('Connecting to SSH...', _TerminalLineType.system);
    _addTerminalLine('Host: $sshHost:$sshPort', _TerminalLineType.info);

    try {
      _sshProcess = await Process.start(
        'plink',
        [
          '-ssh',
          '-l',
          sshUser,
          '-pw',
          _currentPassword,
          '-P',
          '$sshPort',
          sshHost,
        ],
        mode: ProcessStartMode.normal,
      );

      setState(() {
        _isSSHConnected = true;
        _sshStatus = 'Connected';
      });

      _addTerminalLine(
          'SSH Connected successfully!', _TerminalLineType.success);

      _sshProcess!.stdout.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            _addTerminalLine(line, _TerminalLineType.output);
          }
        }
      });

      _sshProcess!.stderr.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            _addTerminalLine(line, _TerminalLineType.error);
          }
        }
      });

      _sshProcess!.exitCode.then((code) {
        setState(() {
          _isSSHConnected = false;
          _sshStatus = 'Disconnected';
        });
        _addTerminalLine('SSH connection closed (exit code: $code)',
            _TerminalLineType.system);
      });
    } catch (e) {
      _addTerminalLine('SSH connection failed: $e', _TerminalLineType.error);
      _addTerminalLine('Make sure plink.exe is installed or use PuTTY',
          _TerminalLineType.info);
      setState(() {
        _isSSHConnected = false;
        _sshStatus = 'Error';
      });
    }
  }

  void _disconnectSSH() {
    if (_sshProcess != null) {
      _sshProcess!.kill();
      _sshProcess = null;
    }
    setState(() {
      _isSSHConnected = false;
      _sshStatus = 'Disconnected';
    });
    _addTerminalLine('SSH Disconnected', _TerminalLineType.system);
  }

  void _sendCommand(String command) {
    if (command.trim().isEmpty) return;

    _addTerminalLine('> $command', _TerminalLineType.command);

    if (_isSSHConnected && _sshProcess != null) {
      _sshProcess!.stdin.writeln(command);
    } else {
      _addTerminalLine(
          'Not connected to SSH. Command queued.', _TerminalLineType.warning);
    }

    _commandController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Main Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3b82f6), Color(0xFF8b5cf6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(
                  icon: Icon(Icons.image),
                  text: 'AQ///Image Manager',
                ),
                Tab(
                  icon: Icon(Icons.menu_book),
                  text: 'Guide & Manual Tools',
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: AQ Image Manager (Professional Tool)
                const AQImageManager(),
                // Tab 2: Original Guide & Manual Tools
                _buildOriginalContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Original content (Guide + Manual SSH Tools)
  Widget _buildOriginalContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        if (isWide) {
          return Row(
            children: [
              // Left Pane - Guide & Paths
              Expanded(
                flex: 3,
                child: _buildLeftPane(),
              ),
              const SizedBox(width: 16),
              // Right Pane - Tools
              Expanded(
                flex: 2,
                child: _buildRightPane(),
              ),
            ],
          );
        } else {
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: const Color(0xFF3b82f6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(text: 'Guide', icon: Icon(Icons.menu_book)),
                      Tab(text: 'Tools', icon: Icon(Icons.build)),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildLeftPane(),
                      _buildRightPane(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildLeftPane() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.image, color: Color(0xFF3b82f6), size: 28),
              const SizedBox(width: 12),
              const Text(
                'NBT Image Retrofit Guide',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: () => setState(() {}),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Requirements
                _buildSectionCard(
                  icon: Icons.checklist,
                  iconColor: Colors.green,
                  title: 'Requirements & Tools',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRequirementWithButton(
                          'Feature Installer Windows 64bit',
                          'Launch',
                          () => _launchPlussProgram('FeatureInstaller.exe')),
                      _buildRequirementWithButton(
                          'FlashXcode ToolKit 3.5',
                          'Launch',
                          () => _launchPlussProgram(
                              'FlashXcode ToolKit 3.5.exe')),
                      _buildRequirementWithButton('BMR-MGU Tool', 'Launch',
                          () => _launchPlussProgram('BMR-MGUTool.exe')),
                      const Divider(color: Colors.white24, height: 24),
                      _buildRequirementItem('WinSCP for file transfer'),
                      _buildRequirementItem('PuTTY for SSH access'),
                      _buildRequirementItem(
                          'PNG images (378x243 pixels, 32bit)'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Unit Selector
                _buildSectionCard(
                  icon: Icons.vpn_key,
                  iconColor: Colors.amber,
                  title: 'Select Unit Type',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _unitPasswords.keys.map((unit) {
                          final isSelected = _selectedUnit == unit;
                          return ChoiceChip(
                            label: Text(unit),
                            selected: isSelected,
                            selectedColor: AQColors.accent.withOpacity(0.3),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            labelStyle: TextStyle(
                              color:
                                  isSelected ? AQColors.accent : Colors.white,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedUnit = unit),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text(
                              'Password: $_currentPassword',
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 14,
                                color: Color(0xFF00ffd0),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              color: AQColors.accent,
                              onPressed: () => _copyToClipboard(
                                  _currentPassword, 'Password'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Common Paths
                _buildSectionCard(
                  icon: Icons.folder_special,
                  iconColor: Colors.orange,
                  title: 'Image Paths (Click to copy)',
                  child: Column(
                    children: _commonPaths.entries
                        .map((e) => _buildPathItem(e.key, e.value))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Guide Steps
                _buildSectionCard(
                  icon: Icons.menu_book,
                  iconColor: Colors.blue,
                  title: 'Quick Guide',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGuideStep(
                          '1', 'Enable SSH using Feature Installer or HU Tool'),
                      _buildGuideStep(
                          '2', 'Connect via PuTTY/WinSCP using credentials'),
                      _buildGuideStep('3',
                          'For NBT2-EVO: Copy SCP to /bin/ from USB first'),
                      _buildGuideStep(
                          '4', 'Navigate to paths above and replace images'),
                      _buildGuideStep('5', 'Reboot head unit to apply changes'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ZGW Search & Control
          _buildZGWSection(),
          const SizedBox(height: 16),
          // SSH Connection
          _buildSSHSection(),
          const SizedBox(height: 16),
          // Quick SSH Commands
          _buildSSHCommandsSection(),
          const SizedBox(height: 16),
          // Terminal Output
          _buildTerminalSection(),
        ],
      ),
    );
  }

  Widget _buildZGWSection() {
    return Consumer<ZGWProvider>(
      builder: (context, zgwProvider, _) {
        return _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF3b82f6)),
                  const SizedBox(width: 8),
                  const Text(
                    'ZGW Search & Control',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: zgwProvider.isConnected
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          zgwProvider.isConnected
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: zgwProvider.isConnected
                              ? Colors.green
                              : Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          zgwProvider.isConnected
                              ? 'Connected'
                              : 'Disconnected',
                          style: TextStyle(
                            color: zgwProvider.isConnected
                                ? Colors.green
                                : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // VIN & IP Info
              if (zgwProvider.vin.isNotEmpty) ...[
                _buildInfoRow('VIN', zgwProvider.vin),
                _buildInfoRow('ZGW IP', zgwProvider.zgwIp),
                _buildInfoRow('HU IP', zgwProvider.huIp),
                const SizedBox(height: 12),
              ],
              // Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: Icons.play_arrow,
                    label: 'Start Search',
                    color: const Color(0xFF3b82f6),
                    onPressed: zgwProvider.isSearching
                        ? null
                        : () {
                            zgwProvider.startSearch();
                            _addTerminalLine('Starting ZGW search...',
                                _TerminalLineType.system);
                          },
                  ),
                  _ActionButton(
                    icon: Icons.stop,
                    label: 'Stop',
                    color: Colors.orange,
                    onPressed: !zgwProvider.isSearching
                        ? null
                        : () {
                            zgwProvider.stopSearch();
                            _addTerminalLine(
                                'ZGW search stopped', _TerminalLineType.system);
                          },
                  ),
                  _ActionButton(
                    icon: Icons.restart_alt,
                    label: 'Reboot MGU',
                    color: Colors.red,
                    onPressed: !zgwProvider.isConnected
                        ? null
                        : () async {
                            _addTerminalLine(
                                'Rebooting MGU...', _TerminalLineType.system);
                            await zgwProvider.sendUdsCommand('11 01');
                          },
                  ),
                ],
              ),
              // Search Status
              if (zgwProvider.isSearching) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3b82f6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Searching... ${zgwProvider.searchProgress}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSSHSection() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, color: Color(0xFF00ffd0)),
              const SizedBox(width: 8),
              const Text(
                'SSH Connection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isSSHConnected
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _sshStatus,
                  style: TextStyle(
                    color: _isSSHConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Connection Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Host', sshHost),
                _buildInfoRow('Port', '$sshPort'),
                _buildInfoRow('User', sshUser),
                _buildInfoRow('Password', _currentPassword),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // SSH Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.open_in_new,
                label: 'Open PuTTY',
                color: const Color(0xFF8b5cf6),
                onPressed: _openPuTTY,
              ),
              _ActionButton(
                icon: Icons.folder_open,
                label: 'Open WinSCP',
                color: Colors.teal,
                onPressed: _openWinSCP,
              ),
              _ActionButton(
                icon: Icons.link,
                label: 'Connect SSH',
                color: const Color(0xFF3b82f6),
                onPressed: _isSSHConnected ? null : _connectSSH,
              ),
              _ActionButton(
                icon: Icons.link_off,
                label: 'Disconnect',
                color: Colors.red,
                onPressed: !_isSSHConnected ? null : _disconnectSSH,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSSHCommandsSection() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.code, color: Color(0xFFf59e0b)),
              SizedBox(width: 8),
              Text(
                'Quick SSH Commands',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sshCommands.map((cmd) {
              return _ActionButton(
                icon: Icons.play_arrow,
                label: cmd['name']!,
                color: Colors.blueGrey,
                onPressed: () => _sendCommand(cmd['cmd']!),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalSection() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.computer, color: Color(0xFF00ffd0)),
              const SizedBox(width: 8),
              const Text(
                'Terminal Output',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white54, size: 20),
                onPressed: _clearTerminal,
                tooltip: 'Clear Terminal',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Terminal Output
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF0d1117),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF30363d)),
            ),
            child: ListView.builder(
              controller: _terminalScrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _terminalLines.length,
              itemBuilder: (context, index) {
                final line = _terminalLines[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    line.text,
                    style: TextStyle(
                      color: line.color,
                      fontFamily: 'Consolas',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Command Input
          Row(
            children: [
              const Text('\$ ', style: TextStyle(color: Color(0xFF00ffd0))),
              Expanded(
                child: TextField(
                  controller: _commandController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Consolas',
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter command...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: _sendCommand,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF3b82f6)),
                onPressed: () => _sendCommand(_commandController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white54,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementWithButton(
      String text, String buttonText, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AQColors.accent.withOpacity(0.3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(60, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathItem(String name, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _copyToClipboard(path, name),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.folder, size: 16, color: Colors.amber.shade300),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      path,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Consolas',
                        color: Colors.white.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.copy, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3b82f6), Color(0xFF8b5cf6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
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
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Color(0xFF00ffd0),
                fontFamily: 'Consolas',
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 14, color: Colors.white38),
            onPressed: () => _copyToClipboard(value, label),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ============ Helper Classes ============

enum _TerminalLineType {
  command,
  output,
  error,
  system,
  info,
  success,
  warning
}

class _TerminalLine {
  final String text;
  final _TerminalLineType type;

  _TerminalLine({required this.text, required this.type});

  Color get color {
    switch (type) {
      case _TerminalLineType.command:
        return const Color(0xFF00ffd0);
      case _TerminalLineType.output:
        return Colors.white;
      case _TerminalLineType.error:
        return const Color(0xFFef4444);
      case _TerminalLineType.system:
        return const Color(0xFF3b82f6);
      case _TerminalLineType.info:
        return Colors.white70;
      case _TerminalLineType.success:
        return const Color(0xFF22c55e);
      case _TerminalLineType.warning:
        return const Color(0xFFf59e0b);
    }
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color : color.withOpacity(0.3),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: onPressed != null ? 4 : 0,
      ),
    );
  }
}

/// Startup Animation Guide class - separate widget for startup animation info
class _StartupAnimationGuide extends StatefulWidget {
  const _StartupAnimationGuide();

  @override
  State<_StartupAnimationGuide> createState() => _StartupAnimationGuideState();
}

class _StartupAnimationGuideState extends State<_StartupAnimationGuide>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Map<String, String> _commonPaths = {
    'M Key Display Path 1':
        '/net/hu-omap/fs/sda0/opt/hmi/ID5/data/ro/bmw/id61/assetDB/Domains/content_preview/PTA_Preview_Guest',
    'M Key Display Path 2':
        '/net/hu-omap/fs/sda0/opt/hmi/ID5/data/ro/bmw/id61/assetDB/Domains/content_preview/cp_fahreprofil_aktivieren',
    'Vehicle Images (ID6)':
        'hu-omap://opt/hmi/ID5/data/ro/bmw/id61/assetDB/Domains/Main/Heroes',
    'Sound Logo Path 1':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/Overlays/bo_logo',
    'Sound Logo Path 2':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/Overlays/bw_logo',
    'ConnectedDrive Logo 1':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/ConnectedDrive/online',
    'ConnectedDrive Logo 2':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/ConnectedDrive/internet',
    'ConnectedDrive Preview 1':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/content_preview_connected_drive',
    'ConnectedDrive Preview 2':
        'opt/hmi/ID5/data/ro/common/assetDB/Domains/content_preview_hauptziel',
    'Startup Animation': '/hu-omap/fs/sda0/opt/car/data/eva/images',
  };

  final Map<String, String> _unitPasswords = {
    'NBT1/NBT2EVO': 'ts&SK412',
    'EntryNAV': 'Entry0?Evo!',
    'CIC old': 'cic0803',
    'CIC new': 'Hm83stN',
  };

  String _selectedUnit = 'NBT1/NBT2EVO';

  final List<String> _vehicleModels = [
    // F-Series
    'hero_myvehicle_F06',
    'hero_myvehicle_F12',
    'hero_myvehicle_F13',
    'hero_myvehicle_F15',
    'hero_myvehicle_F16',
    'hero_myvehicle_F20',
    'hero_myvehicle_F21',
    'hero_myvehicle_F22',
    'hero_myvehicle_F23',
    'hero_myvehicle_F30',
    'hero_myvehicle_F31',
    'hero_myvehicle_F32',
    'hero_myvehicle_F33',
    'hero_myvehicle_F34',
    'hero_myvehicle_F36',
    'hero_myvehicle_F39',
    'hero_myvehicle_F40',
    'hero_myvehicle_F44',
    'hero_myvehicle_F45',
    'hero_myvehicle_F46',
    'hero_myvehicle_F48',
    'hero_myvehicle_F52',
    // G-Series
    'hero_myvehicle_G01',
    'hero_myvehicle_G02',
    'hero_myvehicle_G11',
    'hero_myvehicle_G20',
    'hero_myvehicle_G21',
    'hero_myvehicle_G29',
    'hero_myvehicle_G30',
    'hero_myvehicle_G31',
    'hero_myvehicle_G32',
  ];

  final List<Map<String, dynamic>> _guideSteps = [
    {
      'step': 1,
      'title': 'Requirements',
      'description': '''You need:
• Feature Installer Windows 64bit v1.0.14.7
• WinSCP for file transfer
• PuTTY for SSH access
• PNG images (378x243 pixels, 32bit)''',
      'image': null,
    },
    {
      'step': 2,
      'title': 'SSH Connection',
      'description': '''Connect via SSH to the head unit:
Host: 169.254.199.119
Port: 22
Username: root
Password: (see unit type selector above)''',
      'image': null,
      'showCredentials': true,
    },
    {
      'step': 3,
      'title': 'Mount Filesystem',
      'description':
          'Mount the filesystem as read-write to allow modifications:',
      'commands': ['mount -uw /fs/sda0'],
      'image': null,
    },
    {
      'step': 4,
      'title': 'Navigate to Image Path',
      'description': 'Navigate to the path where images are stored:',
      'showPaths': true,
      'image': null,
    },
    {
      'step': 5,
      'title': 'Startup Animation',
      'description':
          '''For startup animation replacement, the file is located at:
eva_welcome_0x01_0x0_0x003_0x00.avi

Other .avi videos and images can also be replaced.
You might need to code the Head Unit (HU) to use the M startup animation.''',
      'image': null,
      'showAnimationPath': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 $label copied!'),
        backgroundColor: AQColors.accent,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGuideTab(),
              _buildPathsTab(),
              _buildToolsTab(),
            ],
          ),
        ),
      ],
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
          Tab(icon: Icon(Icons.menu_book_rounded), text: 'Guide'),
          Tab(icon: Icon(Icons.folder_rounded), text: 'Paths'),
          Tab(icon: Icon(Icons.build_rounded), text: 'Tools'),
        ],
      ),
    );
  }

  Widget _buildGuideTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left - Guide Content
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          const Text(
                            '🖼️ NBT Image Change Retrofit Guide',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This guide shows how to change your vehicle image and add M Key display on NBT systems.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Requirements
                          _buildRequirementsCard(),
                          const SizedBox(height: 16),

                          // Unit Selector
                          _buildUnitSelector(),
                          const SizedBox(height: 16),

                          // Step by step guide
                          ..._guideSteps.map((step) => _buildStepCard(step)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Right - Terminal & Controls
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSSHControlsCard(),
                        const SizedBox(height: 16),
                        SizedBox(height: 400, child: _buildTerminalCard()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequirementsCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: Colors.blue, size: 22),
              SizedBox(width: 8),
              Text(
                '🧰 Requirements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirementItem('Feature Installer Windows 64bit v1.0.14.7'),
          _buildRequirementItem('WinSCP for file transfer'),
          _buildRequirementItem('PuTTY for SSH access'),
          _buildRequirementItem('PNG images (378x243 pixels, 32bit)'),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔐 Select Unit Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _unitPasswords.keys.map((unit) {
              final isSelected = _selectedUnit == unit;
              return ChoiceChip(
                label: Text(unit),
                selected: isSelected,
                selectedColor: AQColors.accent.withOpacity(0.3),
                backgroundColor: Colors.white.withOpacity(0.05),
                labelStyle: TextStyle(
                  color: isSelected ? AQColors.accent : Colors.white,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _selectedUnit = unit),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AQColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.vpn_key, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Password: ${_unitPasswords[_selectedUnit]}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  color: AQColors.accent,
                  onPressed: () => _copyToClipboard(
                    _unitPasswords[_selectedUnit]!,
                    'Password',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step) {
    final isWarning = step['isWarning'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isWarning
                    ? Colors.red.withOpacity(0.2)
                    : AQColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '📋 STEP ${step['step']}',
                    style: TextStyle(
                      color: isWarning ? Colors.red : AQColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              step['title'],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isWarning ? Colors.red : Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              step['description'],
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
                height: 1.6,
              ),
            ),

            // Commands if any
            if (step['commands'] != null) ...[
              const SizedBox(height: 12),
              ...((step['commands'] as List<String>).map((cmd) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => _copyToClipboard(cmd, 'Command'),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cmd,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ),
                          const Icon(Icons.copy, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              })),
            ],

            // Show credentials
            if (step['showCredentials'] == true) ...[
              const SizedBox(height: 12),
              _buildCredentialsDisplay(),
            ],

            // Show paths
            if (step['showPaths'] == true) ...[
              const SizedBox(height: 12),
              ..._commonPaths.entries
                  .where((e) => !e.key.contains('Animation'))
                  .map((e) {
                return _buildPathItem(e.key, e.value);
              }),
            ],

            // Show animation path
            if (step['showAnimationPath'] == true) ...[
              const SizedBox(height: 12),
              _buildPathItem(
                  'Startup Animation', _commonPaths['Startup Animation']!),
            ],

            // Image if any
            if (step['image'] != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  step['image'],
                  fit: BoxFit.contain,
                  height: 150,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('Image not found',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsDisplay() {
    final zgw = context.watch<ZGWProvider>();
    final ip = zgw.huIp.isNotEmpty
        ? zgw.huIp
        : (zgw.zgwIp.isNotEmpty ? zgw.zgwIp : '192.168.x.x');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCredentialRow('Host/IP', ip),
          _buildCredentialRow('Port', '22'),
          _buildCredentialRow('Username', 'root'),
          _buildCredentialRow('Password', _unitPasswords[_selectedUnit]!),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            color: AQColors.accent,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _copyToClipboard(value, label),
          ),
        ],
      ),
    );
  }

  Widget _buildPathItem(String name, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _copyToClipboard(path, name),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.folder, size: 16, color: Colors.amber.shade300),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      path,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.white.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.copy, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Common Paths
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder_special, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '📁 Common Paths (Click to copy)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._commonPaths.entries
                    .map((e) => _buildPathItem(e.key, e.value)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle Models
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_car, color: Colors.blue, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '🚗 Vehicle Model Paths (Click to copy)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _vehicleModels.map((model) {
                    return ActionChip(
                      label: Text(model.replaceAll('hero_myvehicle_', '')),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                      onPressed: () => _copyToClipboard(model, 'Model'),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Boot Animation Generator
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.movie_creation, color: Colors.purple, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '🎬 Boot Animation Generator',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildToolStep('1️⃣', 'Install/Launch ffmpeg.exe',
                    'Launch ffmpeg', Colors.green),
                _buildToolStep('2️⃣', 'Run evoAQ.exe from attachments',
                    'Launch evoAQ', Colors.blue),
                _buildToolStep('3️⃣', 'Follow program instructions',
                    'Help Guide', Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Attachments
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.attachment, color: Colors.teal, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '📎 Attachments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Sample Image
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/m_key_sample.png',
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text('M Key Sample',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Download buttons
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _downloadSCPToDesktop(),
                              icon: const Icon(Icons.download),
                              label: const Text('Download SCP'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _launchUrl('https://wa.link/dwgks8'),
                              icon: const Icon(Icons.image),
                              label: const Text('M Key Images'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contact
          GlassCard(
            child: Column(
              children: [
                const Text(
                  '📞 Need Help?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _launchUrl('https://wa.link/dwgks8'),
                      icon: const Icon(Icons.chat),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _launchUrl('https://aqbimmer.com'),
                      icon: const Icon(Icons.language),
                      label: const Text('AQ///bimmer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AQColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolStep(
      String number, String text, String buttonText, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            number,
            style: TextStyle(fontSize: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
          OutlinedButton(
            onPressed: () {
              if (buttonText.contains('ffmpeg')) {
                _launchAttachmentLocal('ffmpeg.exe');
              } else if (buttonText.contains('evoAQ')) {
                _launchAttachmentLocal('evoAQ.exe');
              } else if (buttonText.contains('Guide') ||
                  buttonText.contains('Help')) {
                _showGuideDialog();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
            ),
            child: Text(buttonText, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String get _basePath {
    final exeDir = Platform.resolvedExecutable;
    return path_lib.dirname(exeDir);
  }

  Future<void> _launchAttachmentLocal(String filename) async {
    try {
      final possiblePaths = [
        // ResourceDecryptor path for encrypted builds
        path_lib.join(ResourceDecryptor.attachmentsPath, filename),
        // Flutter build output paths
        path_lib.join(_basePath, 'data', 'flutter_assets', 'assets',
            'attachments', filename),
        path_lib.join(
            _basePath, 'flutter_assets', 'assets', 'attachments', filename),
        path_lib.join(_basePath, 'attachments', filename),
        // Development path
        path_lib.join(
            Directory.current.path, 'assets', 'attachments', filename),
      ];

      for (final filePath in possiblePaths) {
        final file = File(filePath);
        if (await file.exists()) {
          await Process.start(filePath, [],
              mode: ProcessStartMode.detached, runInShell: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ $filename launched successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $filename not found in attachments folder'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error launching $filename: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Boot Animation Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Steps to create boot animation:'),
              SizedBox(height: 8),
              Text('1. Use ffmpeg to convert video to images'),
              Text('2. Rename images to sequence format'),
              Text('3. Use evoAQ to package images'),
              Text('4. Upload to head unit via SSH'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSSHControlsCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal, color: Colors.green, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'SSH Controls',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick SSH Commands
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSSHCommandButton('Mount RW', 'mount -uw /fs/sda0', zgw),
                  _buildSSHCommandButton(
                      'Copy SCP', 'cp /fs/usb0/scp /bin/', zgw),
                  _buildSSHCommandButton('chmod', 'chmod 0775 /bin/scp', zgw),
                  _buildSSHCommandButton('Mount RO', 'mount -ur /fs/sda0', zgw),
                  _buildSSHCommandButton('Reboot', 'reboot', zgw),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSSHCommandButton(String label, String command, ZGWProvider zgw) {
    return ActionChip(
      label: Text(label),
      backgroundColor: Colors.green.withOpacity(0.1),
      labelStyle: const TextStyle(color: Colors.green, fontSize: 11),
      onPressed: () {
        _copyToClipboard(command, label);
        zgw.addLog('📋 Copied: $command', 'green');
      },
    );
  }

  Widget _buildTerminalCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgw, _) {
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.computer, color: Colors.blue, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    '💻 Terminal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.cleaning_services, size: 18),
                    color: Colors.grey,
                    onPressed: () => zgw.clearLogs(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: zgw.logMessages.length,
                    itemBuilder: (context, index) {
                      final log = zgw.logMessages[index];
                      return Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: _getLogColorFromMessage(log),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getLogColorFromMessage(String message) {
    if (message.contains('✅') ||
        message.contains('Success') ||
        message.contains('green')) {
      return Colors.greenAccent;
    } else if (message.contains('❌') ||
        message.contains('Error') ||
        message.contains('red')) {
      return Colors.redAccent;
    } else if (message.contains('📋') ||
        message.contains('📥') ||
        message.contains('blue')) {
      return Colors.lightBlueAccent;
    } else if (message.contains('⚠️') ||
        message.contains('Warning') ||
        message.contains('orange')) {
      return Colors.orangeAccent;
    }
    return Colors.white70;
  }

  // ignore: unused_element
  Color _getLogColor(String? type) {
    switch (type) {
      case 'green':
        return Colors.greenAccent;
      case 'red':
        return Colors.redAccent;
      case 'blue':
        return Colors.lightBlueAccent;
      case 'orange':
        return Colors.orangeAccent;
      default:
        return Colors.white70;
    }
  }

  Future<void> _downloadSCPToDesktop() async {
    final zgw = context.read<ZGWProvider>();
    zgw.addLog('📥 Downloading SCP to Desktop...', 'blue');

    try {
      final desktopPath =
          '${Platform.environment['USERPROFILE']}\\Desktop\\scp';

      // Use ResourceDecryptor for both encrypted and dev builds
      final srcPath = path_lib.join(ResourceDecryptor.attachmentsPath, 'scp');

      // Copy file
      zgw.addLog('📁 Copying from: $srcPath to: $desktopPath', 'info');

      // Try to copy from assets
      final result = await Process.run(
        'xcopy',
        [srcPath, desktopPath, '/E', '/I', '/Y'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        zgw.addLog('✅ SCP downloaded to Desktop!', 'green');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ SCP downloaded to Desktop!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        zgw.addLog('⚠️ Download may have failed: ${result.stderr}', 'orange');
      }
    } catch (e) {
      zgw.addLog('❌ Error: $e', 'red');
    }
  }
}
