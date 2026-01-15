import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path_lib;
import 'package:provider/provider.dart';

import '../../core/services/nbt_ssh_service.dart';
import '../../core/services/resource_decryptor.dart';
import '../../core/providers/zgw_provider.dart';

/// AQ///Evo Image Manager - Professional BMW NBT Image Swap Tool
/// Ported from AQtool.py with enhanced Flutter UI
/// Supports: Hero Images, Clock Backgrounds, Boot Animation, Logos
class AQImageManager extends StatefulWidget {
  const AQImageManager({super.key});

  @override
  State<AQImageManager> createState() => _AQImageManagerState();
}

class _AQImageManagerState extends State<AQImageManager>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late NbtSshService _sshService;

  // Image selection state
  String _selectedBrand = 'bmw';
  String _selectedModel = 'G30';
  String _imageType = 'Hero Image';
  String _clockType = 'Comfort';
  String _logoType = 'bo';

  // Selected files
  String? _selectedFilePath;
  final Map<String, String?> _selectedClockImages = {};

  // Preview
  Uint8List? _previewBytes;
  bool _isLoadingPreview = false;

  // Asset paths
  String? _clockImagesPath;
  String? _heroImagesPath;

  // Upload state
  bool _isUploading = false;

  // Terminal
  final ScrollController _terminalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _sshService = NbtSshService();

    _sshService.addListener(_onSshServiceUpdate);
    _initAssetPaths();
  }

  Future<void> _initAssetPaths() async {
    // Get the clock images folder path
    final executableDir = path_lib.dirname(Platform.resolvedExecutable);

    // Try different possible paths for assets
    final possiblePaths = [
      path_lib.join(
          executableDir, 'data', 'flutter_assets', 'assets', 'clock_images'),
      path_lib.join(executableDir, 'assets', 'clock_images'),
      path_lib.join(Directory.current.path, 'assets', 'clock_images'),
      r'D:\Flutter apps\flutter_app\assets\clock_images',
    ];

    for (final p in possiblePaths) {
      if (await Directory(p).exists()) {
        _clockImagesPath = p;
        debugPrint('Found clock_images at: $p');
        break;
      }
    }

    // Hero images path
    final heroImagePaths = [
      path_lib.join(
          executableDir, 'data', 'flutter_assets', 'assets', 'hero_images'),
      path_lib.join(executableDir, 'assets', 'hero_images'),
      path_lib.join(Directory.current.path, 'assets', 'hero_images'),
      r'D:\Flutter apps\flutter_app\assets\hero_images',
    ];

    for (final p in heroImagePaths) {
      if (await Directory(p).exists()) {
        _heroImagesPath = p;
        debugPrint('Found hero_images at: $p');
        break;
      }
    }

    if (_heroImagesPath == null) {
      debugPrint('WARNING: hero_images path not found!');
      debugPrint('Checked paths: $heroImagePaths');
    }

    // Load initial model preview
    if (_heroImagesPath != null) {
      _loadModelPreview();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sshService.removeListener(_onSshServiceUpdate);
    _terminalScrollController.dispose();
    super.dispose();
  }

  void _onSshServiceUpdate() {
    if (mounted) setState(() {});
    // Auto-scroll terminal
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0a0a0f),
            Color(0xFF1a1a2e),
            Color(0xFF16213e),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header with tabs
          _buildHeader(),

          // Main content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConnectionTab(),
                _buildImageSwapTab(),
                _buildBatchUploadTab(),
                _buildTerminalTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3b82f6), Color(0xFF8b5cf6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AQ///Evo Image Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Professional BMW NBT Image Swap Tool',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Connection status
              _buildConnectionStatusBadge(),
            ],
          ),
          const SizedBox(height: 16),
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3b82f6), Color(0xFF8b5cf6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.link), text: 'Connection'),
                Tab(icon: Icon(Icons.image), text: 'Image Swap'),
                Tab(icon: Icon(Icons.cloud_upload), text: 'Batch Upload'),
                Tab(icon: Icon(Icons.terminal), text: 'Terminal'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusBadge() {
    final isConnected = _sshService.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.cancel,
            color: isConnected ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _sshService.connectionStatus,
            style: TextStyle(
              color: isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_sshService.scpInstalled) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SCP',
                style: TextStyle(color: Colors.blue, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ Connection Tab ============
  Widget _buildConnectionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Connection controls
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildUnitSelectionCard(),
                const SizedBox(height: 16),
                _buildConnectionCard(),
                const SizedBox(height: 16),
                _buildZGWSearchCard(),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right side - Quick actions & SCP install
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildScpInstallCard(),
                const SizedBox(height: 16),
                _buildQuickActionsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelectionCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_input_component, color: Color(0xFF3b82f6)),
              SizedBox(width: 8),
              Text(
                'Select Unit Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NbtSshService.unitConfigs.entries.map((entry) {
              final isSelected = _sshService.selectedUnit == entry.key;
              return ChoiceChip(
                label: Text(entry.key),
                selected: isSelected,
                selectedColor: const Color(0xFF3b82f6).withOpacity(0.3),
                backgroundColor: Colors.white.withOpacity(0.05),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF3b82f6) : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  _sshService.selectUnit(entry.key);
                  setState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Credentials display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                _buildCredentialRow('User', _sshService.currentUser),
                const SizedBox(height: 8),
                _buildCredentialRow('Password', _sshService.currentPassword),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      children: [
        Icon(Icons.vpn_key, size: 14, color: Colors.amber.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00ffd0),
              fontFamily: 'Consolas',
              fontSize: 13,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          color: Colors.white54,
          onPressed: () => _copyToClipboard(value, label),
        ),
      ],
    );
  }

  Widget _buildConnectionCard() {
    final zgwProvider = context.watch<ZGWProvider>();
    final suggestedIp =
        zgwProvider.huIp.isNotEmpty ? zgwProvider.huIp : '169.254.199.119';

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link, color: Color(0xFF22c55e)),
              SizedBox(width: 8),
              Text(
                'SSH Connection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // IP Input
          TextField(
            controller: TextEditingController(text: suggestedIp),
            style: const TextStyle(color: Colors.white, fontFamily: 'Consolas'),
            decoration: InputDecoration(
              labelText: 'Head Unit IP',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.computer, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (ip) => _connectToUnit(ip),
          ),
          const SizedBox(height: 16),
          // Connection buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sshService.isConnecting
                      ? null
                      : () => _connectToUnit(suggestedIp),
                  icon: _sshService.isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                      _sshService.isConnecting ? 'Connecting...' : 'Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22c55e),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sshService.isConnected
                      ? () => _sshService.disconnect()
                      : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZGWSearchCard() {
    return Consumer<ZGWProvider>(
      builder: (context, zgwProvider, _) {
        return _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF8b5cf6)),
                  const SizedBox(width: 8),
                  const Text(
                    'ZGW Auto-Discovery',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (zgwProvider.isSearching)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (zgwProvider.vin.isNotEmpty) ...[
                _buildInfoRow('VIN', zgwProvider.vin),
                _buildInfoRow('ZGW IP', zgwProvider.zgwIp),
                _buildInfoRow('HU IP', zgwProvider.huIp),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: zgwProvider.isSearching
                          ? null
                          : () => zgwProvider.startSearch(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8b5cf6),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: zgwProvider.isSearching
                        ? () => zgwProvider.stopSearch()
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
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

  Widget _buildScpInstallCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.download_for_offline,
                color: _sshService.scpInstalled ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              const Text(
                'SCP Binary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _sshService.scpInstalled
                ? '✅ SCP is installed on the unit'
                : '⚠️ SCP not installed - using SFTP fallback',
            style: TextStyle(
              color: _sshService.scpInstalled ? Colors.green : Colors.orange,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Installing SCP enables faster file transfers. The binary will be uploaded via SFTP and installed to /bin/scp.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sshService.isConnected && !_sshService.scpInstalled
                  ? _installScpBinary
                  : null,
              icon: const Icon(Icons.install_desktop),
              label: const Text('Install SCP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
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
            children: [
              _buildQuickActionButton(
                'Mount RW',
                Icons.lock_open,
                Colors.green,
                () => _sshService.mountReadWrite(),
              ),
              _buildQuickActionButton(
                'Mount RO',
                Icons.lock,
                Colors.orange,
                () => _sshService.mountReadOnly(),
              ),
              _buildQuickActionButton(
                'Reboot',
                Icons.restart_alt,
                Colors.red,
                () => _sshService.rebootUnit(),
              ),
              _buildQuickActionButton(
                'List USB',
                Icons.usb,
                Colors.blue,
                () => _sshService.listUsb(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _sshService.isConnected ? onPressed : null,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
    );
  }

  // ============ Image Swap Tab ============
  Widget _buildImageSwapTab() {
    return Row(
      children: [
        // Left - Controls
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildImageTypeSelector(),
                const SizedBox(height: 16),
                if (_imageType == 'Hero Image') _buildHeroImageControls(),
                if (_imageType == 'Clock Background') _buildClockControls(),
                if (_imageType == 'Boot Animation')
                  _buildBootAnimationControls(),
                if (_imageType == 'Logo') _buildLogoControls(),
                const SizedBox(height: 16),
                _buildUploadButton(),
              ],
            ),
          ),
        ),
        // Right - Preview
        Expanded(
          flex: 3,
          child: _buildPreviewPane(),
        ),
      ],
    );
  }

  Widget _buildImageTypeSelector() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.category, color: Color(0xFF3b82f6)),
              SizedBox(width: 8),
              Text(
                'Image Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Hero Image',
              'Clock Background',
              'Boot Animation',
              'Logo'
            ].map((type) {
              final isSelected = _imageType == type;
              final icons = {
                'Hero Image': Icons.directions_car,
                'Clock Background': Icons.access_time,
                'Boot Animation': Icons.movie,
                'Logo': Icons.branding_watermark,
              };
              return ChoiceChip(
                avatar: Icon(icons[type],
                    size: 16,
                    color: isSelected ? Colors.white : Colors.white54),
                label: Text(type),
                selected: isSelected,
                selectedColor: const Color(0xFF3b82f6),
                backgroundColor: Colors.white.withOpacity(0.05),
                labelStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  setState(() {
                    _imageType = type;
                    _selectedFilePath = null;
                    _previewBytes = null;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImageControls() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_car, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Hero Image Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Brand selector
          Row(
            children: [
              const Text('Brand:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              ...['bmw', 'bmwm', 'rr'].map((brand) {
                final isSelected = _selectedBrand == brand;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(brand.toUpperCase()),
                    selected: isSelected,
                    selectedColor: const Color(0xFF3b82f6),
                    onSelected: (_) => setState(() => _selectedBrand = brand),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          // Model selector
          Row(
            children: [
              const Text('Model:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedModel,
                  dropdownColor: const Color(0xFF1a1a2e),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: (_selectedBrand == 'bmwm'
                          ? NbtSshService.bmwMModels
                          : NbtSshService.bmwModels)
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m,
                              style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedModel = v!);
                    // Load model preview image if available
                    _loadModelPreview();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Model Preview
          if (_previewBytes != null && _selectedFilePath == null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Preview: $_selectedBrand $_selectedModel',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(_previewBytes!,
                        height: 100, fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // File selector
          _buildFilePicker(
            'Select Hero Image',
            ['png', 'jpg', 'jpeg'],
            'PNG/JPG (378×243 pixels)',
          ),
        ],
      ),
    );
  }

  Future<void> _loadModelPreview() async {
    // Try to load a sample hero image for the selected model
    // Priority order: simple name first, then prefixed names
    final modelImageNames = [
      // Simple model names (e.g., G30.png, F30.png)
      '$_selectedModel.png',
      '${_selectedModel.toUpperCase()}.png',
      '${_selectedModel.toLowerCase()}.png',
      // Prefixed names
      'current_id6hero_${_selectedModel.toUpperCase()}.png',
      'current_id6hero_$_selectedModel.png',
      'current_id6_main_${_selectedModel.toLowerCase()}_hero.png',
      'hero_${_selectedModel.toLowerCase()}.png',
      'id6hero_${_selectedModel.toLowerCase()}.png',
      'id6_main_${_selectedModel.toLowerCase()}_hero.png',
      'temp_upload_id6hero_${_selectedModel.toLowerCase()}.png',
      'temp_upload_$_selectedModel.png',
    ];

    debugPrint('Loading model preview for: $_selectedModel');
    debugPrint('Hero images path: $_heroImagesPath');

    if (_heroImagesPath != null) {
      for (final name in modelImageNames) {
        final imagePath = path_lib.join(_heroImagesPath!, name);
        final exists = await File(imagePath).exists();
        debugPrint('Checking: $imagePath - exists: $exists');
        if (exists) {
          debugPrint('Found image: $imagePath');
          await _loadPreview(imagePath);
          return;
        }
      }

      // If no specific model image found, try to load any image from the folder
      debugPrint('No exact match, scanning directory...');
      final dir = Directory(_heroImagesPath!);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File &&
              entity.path.toLowerCase().endsWith('.png') &&
              entity.path
                  .toLowerCase()
                  .contains(_selectedModel.toLowerCase())) {
            debugPrint('Found by scan: ${entity.path}');
            await _loadPreview(entity.path);
            return;
          }
        }
      }
      debugPrint('No image found for model: $_selectedModel');
    } else {
      debugPrint('Hero images path is null!');
    }
  }

  Widget _buildClockControls() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                'Clock Background Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Clock type selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Comfort', 'Sport', 'Eco', 'Scale'].map((type) {
              final isSelected = _clockType == type;
              final hasFile = _selectedClockImages[type] != null;
              return ChoiceChip(
                avatar: hasFile
                    ? const Icon(Icons.check_circle,
                        size: 16, color: Colors.green)
                    : null,
                label: Text(type),
                selected: isSelected,
                selectedColor: const Color(0xFF8b5cf6),
                onSelected: (_) => setState(() => _clockType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildFilePicker(
            'Select Clock Image',
            ['png'],
            'PNG (240×240 pixels)',
            onSelected: (path) {
              setState(() {
                _selectedClockImages[_clockType] = path;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _browseAllClockImages,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse Clock Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.withOpacity(0.3),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _openClockImagesFolder,
                icon: const Icon(Icons.folder),
                label: const Text('Open Folder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.3),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Clock presets
          if (_clockImagesPath != null)
            FutureBuilder<List<String>>(
              future: _getClockPresets(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Presets:',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: snapshot.data!.take(8).map((preset) {
                        return ActionChip(
                          label: Text(preset,
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.purple.withOpacity(0.2),
                          onPressed: () => _loadClockPreset(preset),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Future<List<String>> _getClockPresets() async {
    if (_clockImagesPath == null) return [];
    final dir = Directory(_clockImagesPath!);
    if (!await dir.exists()) return [];

    final presets = <String>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = path_lib.basename(entity.path);
        if (name != 'common' && name != 'clock') {
          presets.add(name);
        }
      }
    }
    return presets;
  }

  Future<void> _loadClockPreset(String presetName) async {
    final presetPath = path_lib.join(_clockImagesPath!, presetName);
    final dir = Directory(presetPath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
        final filename = path_lib.basename(entity.path).toLowerCase();

        if (filename.contains('comfort') || filename.contains('bg_comfort')) {
          _selectedClockImages['Comfort'] = entity.path;
        } else if (filename.contains('sport') ||
            filename.contains('bg_sport')) {
          _selectedClockImages['Sport'] = entity.path;
        } else if (filename.contains('eco') || filename.contains('bg_eco')) {
          _selectedClockImages['Eco'] = entity.path;
        } else if (filename.contains('scale') ||
            filename.contains('bg_scale')) {
          _selectedClockImages['Scale'] = entity.path;
        }
      }
    }

    // Load preview of first found image
    if (_selectedClockImages.isNotEmpty) {
      final firstImage = _selectedClockImages.values
          .firstWhere((v) => v != null, orElse: () => null);
      if (firstImage != null) {
        await _loadPreview(firstImage);
      }
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded preset: $presetName'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  Future<void> _openClockImagesFolder() async {
    if (_clockImagesPath != null &&
        await Directory(_clockImagesPath!).exists()) {
      await Process.run('explorer', [_clockImagesPath!]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clock images folder not found'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildBootAnimationControls() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.movie, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Boot Animation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Text(
              '💡 Use evoAQ.exe to convert videos to the correct AVI format before uploading.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          _buildFilePicker(
            'Select Boot Animation',
            ['avi'],
            'AVI format only',
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _launchAttachment('evoAQ.exe'),
            icon: const Icon(Icons.launch),
            label: const Text('Launch evoAQ Tool'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoControls() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.branding_watermark, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                'Logo Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Logo Type:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              ...['bo', 'bw'].map((type) {
                final isSelected = _logoType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type.toUpperCase()),
                    selected: isSelected,
                    selectedColor: Colors.teal,
                    onSelected: (_) => setState(() => _logoType = type),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilePicker(
            'Select Logo',
            ['png'],
            'PNG format',
          ),
        ],
      ),
    );
  }

  Widget _buildFilePicker(
    String label,
    List<String> extensions,
    String hint, {
    Function(String)? onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedFilePath != null
                            ? path_lib.basename(_selectedFilePath!)
                            : 'No file selected',
                        style: TextStyle(
                          color: _selectedFilePath != null
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _pickFile(extensions, onSelected),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Browse'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3b82f6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPreviewPane() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Preview header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview, color: Colors.white54),
                const SizedBox(width: 8),
                const Text(
                  'Image Preview',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_sshService.isConnected)
                  ElevatedButton.icon(
                    onPressed: _downloadCurrentImage,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download Current'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
          ),
          // Preview content
          Expanded(
            child: _isLoadingPreview
                ? const Center(child: CircularProgressIndicator())
                : _previewBytes != null
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_previewBytes!,
                                fit: BoxFit.contain),
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_outlined,
                                size: 64, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text(
                              'Select an image to preview',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4)),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _sshService.isConnected &&
                _selectedFilePath != null &&
                !_isUploading
            ? _uploadImage
            : null,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.cloud_upload),
        label: Text(_isUploading ? 'Uploading...' : 'Upload Image'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF22c55e),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ============ Batch Upload Tab ============
  Widget _buildBatchUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Batch Upload - All Clock Images',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload all clock background images at once. Select files named with their type (comfort, sport, eco, scale).',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                // Show selected clock images
                ..._selectedClockImages.entries
                    .where((e) => e.value != null)
                    .map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(e.key,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            path_lib.basename(e.value!),
                            style:
                                TextStyle(color: Colors.white.withOpacity(0.6)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _browseAllClockImages,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Browse Clock Images'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sshService.isConnected &&
                                _selectedClockImages.values
                                    .any((v) => v != null)
                            ? _uploadAllClockImages
                            : null,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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

  // ============ Terminal Tab ============
  Widget _buildTerminalTab() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Column(
        children: [
          // Terminal header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF161b22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: Colors.amber, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 16),
                const Text('SSH Terminal',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.white54, size: 18),
                  onPressed: () => _sshService.clearLogs(),
                  tooltip: 'Clear',
                ),
              ],
            ),
          ),
          // Terminal output
          Expanded(
            child: ListView.builder(
              controller: _terminalScrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _sshService.logs.length,
              itemBuilder: (context, index) {
                final log = _sshService.logs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '[${log.formattedTime}] ',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11),
                        ),
                        TextSpan(
                          text: log.message,
                          style: TextStyle(
                            color: _getLogColor(log.level),
                            fontFamily: 'Consolas',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Command input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF161b22),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Text('\$ ',
                    style: TextStyle(
                        color: Color(0xFF00ffd0), fontFamily: 'Consolas')),
                Expanded(
                  child: TextField(
                    style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Consolas',
                        fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Enter command...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (cmd) {
                      if (cmd.isNotEmpty && _sshService.isConnected) {
                        _sshService.executeCommand(cmd);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ Helper Methods ============

  Color _getLogColor(SshLogLevel level) {
    switch (level) {
      case SshLogLevel.success:
        return const Color(0xFF22c55e);
      case SshLogLevel.error:
        return const Color(0xFFef4444);
      case SshLogLevel.warning:
        return const Color(0xFFf59e0b);
      case SshLogLevel.command:
        return const Color(0xFF00ffd0);
      case SshLogLevel.output:
        return Colors.white;
      case SshLogLevel.info:
        return const Color(0xFF3b82f6);
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Color(0xFF00ffd0),
                  fontFamily: 'Consolas',
                  fontSize: 12),
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 $label copied!'),
        backgroundColor: const Color(0xFF3b82f6),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _connectToUnit(String ip) async {
    await _sshService.connect(ip);
  }

  Future<void> _installScpBinary() async {
    // Find SCP binary in assets
    final possiblePaths = [
      path_lib.join(ResourceDecryptor.attachmentsPath, 'scp'),
      path_lib.join(Directory.current.path, 'assets', 'attachments', 'scp'),
    ];

    String? scpPath;
    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        scpPath = path;
        break;
      }
    }

    if (scpPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ SCP binary not found in assets/attachments'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _sshService.installScpBinary(scpPath);
  }

  Future<void> _pickFile(List<String> extensions, Function(String)? onSelected,
      {String? initialDirectory}) async {
    // Determine initial directory based on image type
    String? initDir = initialDirectory;
    if (initDir == null) {
      if (_imageType == 'Clock Background' && _clockImagesPath != null) {
        // Try to open the common folder for clock images
        final commonPath = path_lib.join(_clockImagesPath!, 'common');
        if (await Directory(commonPath).exists()) {
          initDir = commonPath;
        } else {
          initDir = _clockImagesPath;
        }
      } else if (_imageType == 'Hero Image' && _heroImagesPath != null) {
        initDir = _heroImagesPath;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      initialDirectory: initDir,
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      setState(() {
        _selectedFilePath = filePath;
      });

      onSelected?.call(filePath);

      // Load preview
      await _loadPreview(filePath);
    }
  }

  Future<void> _browseAllClockImages() async {
    // Open the clock images folder directly
    String? initDir;
    if (_clockImagesPath != null) {
      final commonPath = path_lib.join(_clockImagesPath!, 'common');
      if (await Directory(commonPath).exists()) {
        initDir = commonPath;
      } else {
        initDir = _clockImagesPath;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
      allowMultiple: true,
      initialDirectory: initDir,
    );

    if (result != null) {
      for (final file in result.files) {
        if (file.path == null) continue;
        final filename = path_lib.basename(file.path!).toLowerCase();

        if (filename.contains('comfort')) {
          _selectedClockImages['Comfort'] = file.path;
        } else if (filename.contains('sport')) {
          _selectedClockImages['Sport'] = file.path;
        } else if (filename.contains('eco')) {
          _selectedClockImages['Eco'] = file.path;
        } else if (filename.contains('scale')) {
          _selectedClockImages['Scale'] = file.path;
        }
      }
      setState(() {});
    }
  }

  Future<void> _loadPreview(String filePath) async {
    if (!filePath.toLowerCase().endsWith('.png') &&
        !filePath.toLowerCase().endsWith('.jpg') &&
        !filePath.toLowerCase().endsWith('.jpeg')) {
      return;
    }

    setState(() => _isLoadingPreview = true);

    try {
      final bytes = await File(filePath).readAsBytes();
      setState(() {
        _previewBytes = bytes;
        _isLoadingPreview = false;
      });
    } catch (e) {
      setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _downloadCurrentImage() async {
    final remotePath = _sshService.getRemotePath(
      imageType: _imageType,
      model: _selectedModel,
      brand: _selectedBrand,
      clockType: _clockType,
      logoType: _logoType,
    );

    if (remotePath == null) return;

    final tempDir = await Directory.systemTemp.createTemp('nbt_');
    final localPath =
        path_lib.join(tempDir.path, path_lib.basename(remotePath));

    setState(() => _isLoadingPreview = true);

    final success = await _sshService.downloadFile(remotePath, localPath);

    if (success) {
      await _loadPreview(localPath);
    } else {
      setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedFilePath == null) return;

    setState(() => _isUploading = true);

    bool success = false;

    switch (_imageType) {
      case 'Hero Image':
        success = await _sshService.uploadHeroImage(
            _selectedFilePath!, _selectedModel, _selectedBrand);
        break;
      case 'Clock Background':
        success = await _sshService.uploadClockBackground(
            _selectedFilePath!, _clockType);
        break;
      case 'Boot Animation':
        success = await _sshService.uploadBootAnimation(_selectedFilePath!);
        break;
      case 'Logo':
        success = await _sshService.uploadLogo(_selectedFilePath!, _logoType);
        break;
    }

    setState(() => _isUploading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Image uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Ask to reboot
      final reboot = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('Upload Complete',
              style: TextStyle(color: Colors.white)),
          content: const Text('Reboot head unit to apply changes?',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Reboot Now'),
            ),
          ],
        ),
      );

      if (reboot == true) {
        await _sshService.rebootUnit();
      }
    }
  }

  Future<void> _uploadAllClockImages() async {
    setState(() => _isUploading = true);

    int successCount = 0;
    int failCount = 0;

    for (final entry in _selectedClockImages.entries) {
      if (entry.value != null) {
        final success =
            await _sshService.uploadClockBackground(entry.value!, entry.key);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }
    }

    setState(() => _isUploading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Clock images: $successCount uploaded, $failCount failed'),
        backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
      ),
    );

    if (successCount > 0) {
      await _sshService.rebootUnit();
    }
  }

  Future<void> _launchAttachment(String filename) async {
    final possiblePaths = [
      path_lib.join(ResourceDecryptor.attachmentsPath, filename),
      path_lib.join(Directory.current.path, 'assets', 'attachments', filename),
    ];

    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        await Process.start(path, [],
            runInShell: true, mode: ProcessStartMode.detached);
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $filename not found'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// ============ Glass Card Widget ============
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
          ),
          child: child,
        ),
      ),
    );
  }
}
