import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path_lib;
import 'dart:ui';
import '../../core/providers/zgw_provider.dart';
import '../../core/services/resource_decryptor.dart';

/// HDD Guide Tab - Complete clone from Python version
/// Features: ZGW Search, SSH Connection, HDD Commands, Terminal Output
class HDDGuideTab extends StatefulWidget {
  const HDDGuideTab({super.key});

  @override
  State<HDDGuideTab> createState() => _HDDGuideTabState();
}

class _HDDGuideTabState extends State<HDDGuideTab> {
  // SSH Connection State
  bool _isSSHConnected = false;
  String _sshStatus = 'Disconnected';
  Process? _sshProcess;

  // Terminal Output
  final List<TerminalLine> _terminalLines = [];
  final ScrollController _terminalScrollController = ScrollController();
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _commandFocusNode = FocusNode();

  // SSH Credentials
  static const String sshHost = '169.254.199.119';
  static const int sshPort = 22;
  static const String sshUser = 'root';
  static const String sshPassword = 'ts&SK412';

  // Guide Steps - English translations from Python original
  final List<_GuideStep> _guideSteps = [
    _GuideStep(
      title: '🔍 HOW DO YOU KNOW IF YOU NEED TO CHANGE YOUR HDD?',
      description: '''
Usually when NBT or EVO HDD fails, the head unit starts rebooting, you hear clicking sounds, maps get stuck on loading, bluetooth audio doesn't work, USB drives are not recognized.

Not all symptoms occur together - might be one or several.
      ''',
      imagePath: null,
      commands: [],
    ),
    _GuideStep(
      title: 'STEP 1: Removing Faulty HDD',
      description: '''
• Unscrew four bolts from the top cover (marked red in picture)
• Remove top cover and loosen the centre bolt (marked red)
• Then remove DVD-ROM by lifting it up
• Carefully disconnect the HDD cable and remove the faulty HDD
      ''',
      imagePath: 'assets/images/hdd1.jpg',
      commands: [],
    ),
    _GuideStep(
      title: 'STEP 2: Installing New HDD',
      description: '''
• Assemble everything back, but don't rush to screw all bolts
• Power the unit first to check if it's not rebooting

⚠️ IMPORTANT: If unit is rebooting - Remove HDD, power unit without it, then install HDD. Unit will stop rebooting.
      ''',
      imagePath: 'assets/images/hdd2.jpg',
      commands: [],
    ),
    _GuideStep(
      title: 'STEP 3: Enabling SSH Access',
      description: '''
• Use HU TOOL, Feature Installer, or other methods to activate SSH access
• Feature Installer is recommended as the easiest method
• Make sure SSH is enabled before proceeding to next step
      ''',
      imagePath: 'assets/images/hdd33.jpg',
      commands: [],
    ),
    _GuideStep(
      title: 'STEP 4: Initialize New HDD',
      description: '''
After enabling SSH, use PuTTY or terminal to initialize HDD.

SSH Credentials:
• IP: 169.254.199.119
• Port: 22
• User: root
• Password: ts&SK412

Run these commands in order. After running the first 4 commands, the head unit will reboot. After reboot, login again and run the directories command.
      ''',
      imagePath: 'assets/images/step4_putty.png',
      commands: [
        'create_hdd.sh -c partition',
        'create_hdd.sh -c format',
        'create_hdd.sh -c mount',
        'OnOfIDSICommander appreset',
        'create_hdd.sh -c directories',
      ],
    ),
    _GuideStep(
      title: 'STEP 5: Flashing Your Unit',
      description: '''
• Flash your unit in full (BTLD, SWFL, CAFD, IBAD)
• Or if psdzdata matches, flash only IBADs
• Use E-Sys or compatible flashing tool
• Make sure all firmware is up to date
      ''',
      imagePath: 'assets/images/hdd3.jpg',
      commands: [],
    ),
    _GuideStep(
      title: 'STEP 6: Installing Map Data',
      description: '''
• Download map data for your region
• Copy map files to USB drive
• Insert map update FSC in FSC directory
• Insert USB in car and start map update
• Wait for installation to complete
      ''',
      imagePath: 'assets/images/step5_flash.jpg',
      commands: [],
    ),
    _GuideStep(
      title: 'STEP 7: Install Gracenote',
      description: '''
• Install Gracenote database for music recognition functionality
• This enables album art and song info display
• Copy Gracenote files to appropriate directory

💡 IMPORTANT FACTS:
• Switching from HDD to SSD will NOT improve performance!
• Not all HDDs work with NBT/EVO units - research compatible models
• HDD gets locked immediately when powered up - unlocking is separate procedure
      ''',
      imagePath: 'assets/images/step6_maps.jpg',
      commands: [],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _addTerminalLine('HDD Guide Terminal Ready', TerminalLineType.system);
    _addTerminalLine(
        'Type commands or use the buttons above', TerminalLineType.info);
  }

  @override
  void dispose() {
    _sshProcess?.kill();
    _terminalScrollController.dispose();
    _commandController.dispose();
    _commandFocusNode.dispose();
    super.dispose();
  }

  void _addTerminalLine(String text, TerminalLineType type) {
    setState(() {
      _terminalLines.add(TerminalLine(text: text, type: type));
    });
    // Scroll to bottom
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
    _addTerminalLine('Terminal cleared', TerminalLineType.system);
  }

  Future<void> _openPuTTY() async {
    _addTerminalLine('Opening PuTTY...', TerminalLineType.system);

    try {
      // Get base path
      final exeDir = Directory(Platform.resolvedExecutable).parent.path;

      // Try to find PuTTY in multiple locations
      final puttyPaths = [
        // ResourceDecryptor path for encrypted builds
        path_lib.join(ResourceDecryptor.attachmentsPath, 'putty', 'putty.exe'),
        // Flutter build output path
        path_lib.join(
            exeDir, 'data', 'flutter_assets', 'assets', 'putty', 'putty.exe'),
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
            '📁 Found PuTTY at: $puttyPath', TerminalLineType.info);
        await Process.start(
            puttyPath,
            [
              '-ssh',
              '$sshUser@$sshHost',
              '-P',
              '$sshPort',
              '-pw',
              sshPassword,
            ],
            runInShell: true);
        _addTerminalLine('PuTTY opened successfully', TerminalLineType.success);
      } else {
        // Try to launch PuTTY from PATH
        _addTerminalLine('Trying system PuTTY...', TerminalLineType.info);
        await Process.start(
            'putty',
            [
              '-ssh',
              '$sshUser@$sshHost',
              '-P',
              '$sshPort',
              '-pw',
              sshPassword,
            ],
            runInShell: true);
        _addTerminalLine('PuTTY opened successfully', TerminalLineType.success);
      }
    } catch (e) {
      _addTerminalLine('Error opening PuTTY: $e', TerminalLineType.error);
      _addTerminalLine(
          'Please install PuTTY or add putty.exe to assets/putty folder',
          TerminalLineType.info);
    }
  }

  Future<void> _connectSSH() async {
    if (_isSSHConnected) {
      _addTerminalLine('Already connected to SSH', TerminalLineType.warning);
      return;
    }

    _addTerminalLine('Connecting to SSH...', TerminalLineType.system);
    _addTerminalLine('Host: $sshHost:$sshPort', TerminalLineType.info);

    try {
      // Using plink (PuTTY command line) for SSH
      _sshProcess = await Process.start(
        'plink',
        [
          '-ssh',
          '-l',
          sshUser,
          '-pw',
          sshPassword,
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

      _addTerminalLine('SSH Connected successfully!', TerminalLineType.success);

      // Listen to stdout
      _sshProcess!.stdout.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            _addTerminalLine(line, TerminalLineType.output);
          }
        }
      });

      // Listen to stderr
      _sshProcess!.stderr.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            _addTerminalLine(line, TerminalLineType.error);
          }
        }
      });

      // Handle process exit
      _sshProcess!.exitCode.then((code) {
        setState(() {
          _isSSHConnected = false;
          _sshStatus = 'Disconnected';
        });
        _addTerminalLine('SSH connection closed (exit code: $code)',
            TerminalLineType.system);
      });
    } catch (e) {
      _addTerminalLine('SSH connection failed: $e', TerminalLineType.error);
      _addTerminalLine('Make sure plink.exe is installed or use PuTTY',
          TerminalLineType.info);
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
    _addTerminalLine('SSH Disconnected', TerminalLineType.system);
  }

  void _sendCommand(String command) {
    if (command.trim().isEmpty) return;

    _addTerminalLine('> $command', TerminalLineType.command);

    if (_isSSHConnected && _sshProcess != null) {
      _sshProcess!.stdin.writeln(command);
    } else {
      _addTerminalLine(
          'Not connected to SSH. Command queued.', TerminalLineType.warning);
    }

    _commandController.clear();
    _commandFocusNode.requestFocus();
  }

  void _executeHDDCommand(String command) {
    _addTerminalLine('Executing: $command', TerminalLineType.system);
    _sendCommand(command);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;

          if (isWide) {
            // Desktop layout: Side by side
            return Row(
              children: [
                // Left Pane - Guide
                Expanded(
                  flex: 3,
                  child: _buildGuidePane(),
                ),
                const SizedBox(width: 16),
                // Right Pane - Tools
                Expanded(
                  flex: 2,
                  child: _buildToolsPane(),
                ),
              ],
            );
          } else {
            // Mobile layout: Tabbed
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
                        _buildGuidePane(),
                        _buildToolsPane(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildGuidePane() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.storage, color: Color(0xFF3b82f6), size: 28),
              const SizedBox(width: 12),
              const Text(
                'HDD Installation Guide',
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
          // Steps List
          Expanded(
            child: ListView.builder(
              itemCount: _guideSteps.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                return _buildStepCard(_guideSteps[index], index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(_GuideStep step, int stepNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        initiallyExpanded: stepNumber == 1,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3b82f6), Color(0xFF8b5cf6)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          step.title,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                if (step.imagePath != null && step.imagePath!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        step.imagePath!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            color: Colors.white.withOpacity(0.05),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image_not_supported,
                                      color: Colors.white38, size: 48),
                                  SizedBox(height: 8),
                                  Text('Image not available',
                                      style: TextStyle(color: Colors.white38)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                // Description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    step.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
                // Commands
                if (step.commands.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Commands:',
                    style: TextStyle(
                      color: Color(0xFF00ffd0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...step.commands.map((cmd) => _buildCommandBlock(cmd)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandBlock(String command) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3b82f6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                command,
                style: const TextStyle(
                  color: Color(0xFF00ffd0),
                  fontFamily: 'Consolas',
                  fontSize: 13,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
            onPressed: () => _copyToClipboard(command),
            tooltip: 'Copy',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow,
                color: Color(0xFF3b82f6), size: 20),
            onPressed: () => _executeHDDCommand(command),
            tooltip: 'Execute',
          ),
        ],
      ),
    );
  }

  Widget _buildToolsPane() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ZGW Search & Control
          _buildZGWSection(),
          const SizedBox(height: 16),
          // SSH Connection
          _buildSSHSection(),
          const SizedBox(height: 16),
          // HDD Commands
          _buildHDDCommandsSection(),
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
                                TerminalLineType.system);
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
                                'ZGW search stopped', TerminalLineType.system);
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
                                'Rebooting MGU...', TerminalLineType.system);
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
            onPressed: () => _copyToClipboard(value),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
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
                _buildInfoRow('Password', sshPassword),
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

  Widget _buildHDDCommandsSection() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storage, color: Color(0xFFef4444)),
              SizedBox(width: 8),
              Text(
                'HDD Commands',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Command Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.pie_chart,
                label: 'Partition',
                color: const Color(0xFF3b82f6),
                onPressed: () =>
                    _executeHDDCommand('create_hdd.sh -c partition'),
              ),
              _ActionButton(
                icon: Icons.format_paint,
                label: 'Format',
                color: const Color(0xFF8b5cf6),
                onPressed: () => _executeHDDCommand('create_hdd.sh -c format'),
              ),
              _ActionButton(
                icon: Icons.eject,
                label: 'Mount',
                color: const Color(0xFF00ffd0),
                onPressed: () => _executeHDDCommand('create_hdd.sh -c mount'),
              ),
              _ActionButton(
                icon: Icons.folder,
                label: 'Directories',
                color: const Color(0xFFf59e0b),
                onPressed: () =>
                    _executeHDDCommand('create_hdd.sh -c directories'),
              ),
              _ActionButton(
                icon: Icons.restart_alt,
                label: 'App Reset',
                color: const Color(0xFFef4444),
                onPressed: () =>
                    _executeHDDCommand('OnOfIDSICommander appreset'),
              ),
            ],
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
              const Icon(Icons.code, color: Color(0xFF00ffd0)),
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
          const SizedBox(height: 12),
          // Command Input
          Row(
            children: [
              const Text(
                '\$ ',
                style: TextStyle(
                  color: Color(0xFF00ffd0),
                  fontFamily: 'Consolas',
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _commandController,
                  focusNode: _commandFocusNode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Consolas',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter command...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3b82f6)),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                  ),
                  onSubmitted: _sendCommand,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _sendCommand(_commandController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3b82f6),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.send, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============ Helper Classes ============

class _GuideStep {
  final String title;
  final String description;
  final String? imagePath;
  final List<String> commands;

  _GuideStep({
    required this.title,
    required this.description,
    this.imagePath,
    required this.commands,
  });
}

enum TerminalLineType { command, output, error, system, info, success, warning }

class TerminalLine {
  final String text;
  final TerminalLineType type;

  TerminalLine({required this.text, required this.type});

  Color get color {
    switch (type) {
      case TerminalLineType.command:
        return const Color(0xFF00ffd0);
      case TerminalLineType.output:
        return Colors.white;
      case TerminalLineType.error:
        return const Color(0xFFef4444);
      case TerminalLineType.system:
        return const Color(0xFF3b82f6);
      case TerminalLineType.info:
        return Colors.white70;
      case TerminalLineType.success:
        return const Color(0xFF22c55e);
      case TerminalLineType.warning:
        return const Color(0xFFf59e0b);
    }
  }
}

// ============ UI Components ============

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: onPressed != null ? 4 : 0,
      ),
    );
  }
}
