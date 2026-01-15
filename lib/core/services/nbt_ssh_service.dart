import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_lib;

/// NBT SSH Service - Professional SSH/SCP/SFTP file transfer service
/// Supports multiple protocols for BMW NBT/CIC/EVO head units
/// Based on QNX SSH requirements and BMW unit specifications
class NbtSshService extends ChangeNotifier {
  // ============ Connection State ============
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _scpInstalled = false;
  String _connectionStatus = 'Disconnected';
  String? _connectedIp;
  String _selectedUnit = 'NBT1/NBT2EVO';

  // ============ Logs ============
  final List<SshLogEntry> _logs = [];

  // ============ Unit Configurations ============
  static const Map<String, Map<String, String>> unitConfigs = {
    'NBT1/NBT2EVO': {
      'user': 'root',
      'password': 'ts&SK412',
      'description': 'NBT1 & NBT2 EVO Units',
    },
    'EntryNAV': {
      'user': 'root',
      'password': 'Entry0?Evo!',
      'description': 'Entry NAV Units',
    },
    'CIC old': {
      'user': 'root',
      'password': 'cic0803',
      'description': 'CIC Old Generation',
    },
    'CIC new': {
      'user': 'root',
      'password': 'Hm83stN',
      'description': 'CIC New Generation',
    },
  };

  // ============ Image Paths Configuration ============
  static const Map<String, dynamic> imagePaths = {
    'Hero Image': {
      'bmw':
          '/fs/sda0/opt/hmi/ID5/data/ro/bmw/id6l/assetDB/Domains/Main/Heroes/hero_myvehicle_{model}',
      'bmwm':
          '/fs/sda0/opt/hmi/ID5/data/ro/bmwm/id6l/assetDB/Domains/Main/Heroes/hero_myvehicle_{model}',
      'rr':
          '/fs/sda0/opt/hmi/ID5/data/ro/rr/id6l/assetDB/Domains/Main/Heroes/hero_myvehicle_{model}',
    },
    'Clock Background': {
      'Comfort': 'd293774fd0b852f3tex_bg_comfort_bitmap.png',
      'Sport': '48d3fbf014988e99tex_bg_sport_bitmap.png',
      'Eco': 'cae4b97cfbb74b78tex_bg_eco_bitmap.png',
      'Scale': '2c34333066624a27tex_scale_bitmap.png',
      'basePath':
          '/fs/sda0/opt/hmi/ID5/data/ro/common/widgetasset/clock/bitmaps/',
    },
    'Boot Animation':
        '/fs/sda0/opt/car/data/eva/images/eva_animation_0x01_0x0_0x003_0x00.avi',
    'Logo': {
      'bo':
          '/fs/sda0/repository/istep/opt/hmi/ID5/data/ro/common/assetDB/Domains/Overlays/bo_logo/bo_logo.png',
      'bw':
          '/fs/sda0/repository/istep/opt/hmi/ID5/data/ro/common/assetDB/Domains/Overlays/bw_logo/bw_logo.png',
    },
    'M Key Display': {
      'path1':
          '/net/hu-omap/fs/sda0/opt/hmi/ID5/data/ro/bmw/id61/assetDB/Domains/content_preview/PTA_Preview_Guest',
      'path2':
          '/net/hu-omap/fs/sda0/opt/hmi/ID5/data/ro/bmw/id61/assetDB/Domains/content_preview/cp_fahreprofil_aktivieren',
    },
  };

  // ============ Standard Sizes ============
  static const heroImageSize = (378, 243);
  static const clockImageSize = (240, 240);

  // ============ Vehicle Models ============
  static const List<String> bmwModels = [
    'F06',
    'F10',
    'F12',
    'F13',
    'F15',
    'F16',
    'F20',
    'F21',
    'F22',
    'F23',
    'F30',
    'F31',
    'F32',
    'F33',
    'F34',
    'F36',
    'F39',
    'F40',
    'F44',
    'F45',
    'F46',
    'F48',
    'F52',
    'G01',
    'G02',
    'G11',
    'G20',
    'G21',
    'G29',
    'G30',
    'G31',
    'G32',
  ];

  static const List<String> bmwMModels = [
    'F80',
    'F82',
    'F83',
    'F85',
    'F86',
    'F87',
    'F90',
    'F91',
    'F92',
    'F93',
  ];

  // ============ PuTTY Tools Paths ============
  String? _plinkPath;
  String? _pscpPath;
  String? _psftpPath;
  String? _puttyPath;

  // ============ Upload Configuration ============
  static const int maxRetries = 3;
  static const Duration connectionTimeout = Duration(seconds: 20);
  static const Duration uploadTimeout = Duration(minutes: 10);

  // ============ Host Key Cache ============
  bool _hostKeyAccepted = false;

  // ============ Getters ============
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get scpInstalled => _scpInstalled;
  String get connectionStatus => _connectionStatus;
  String? get connectedIp => _connectedIp;
  String get selectedUnit => _selectedUnit;
  List<SshLogEntry> get logs => List.unmodifiable(_logs);
  String? get puttyPath => _puttyPath;
  bool get hostKeyAccepted => _hostKeyAccepted;

  String get currentUser => unitConfigs[_selectedUnit]?['user'] ?? 'root';
  String get currentPassword =>
      unitConfigs[_selectedUnit]?['password'] ?? 'ts&SK412';

  // ============ Constructor ============
  NbtSshService() {
    _initializePuttyPaths();
  }

  // ============ Initialize PuTTY Paths ============
  Future<void> _initializePuttyPaths() async {
    // Get executable directory for bundled builds
    final executableDir = path_lib.dirname(Platform.resolvedExecutable);

    // Try to find PuTTY tools in various locations
    final possibleBasePaths = [
      // Bundled in build output
      path_lib.join(executableDir, 'data', 'flutter_assets', 'assets',
          'attachments', 'putty'),
      path_lib.join(executableDir, 'data', 'flutter_assets', 'assets', 'putty'),
      path_lib.join(executableDir, 'assets', 'attachments', 'putty'),
      path_lib.join(executableDir, 'assets', 'putty'),
      // Development paths
      path_lib.join(Directory.current.path, 'assets', 'attachments', 'putty'),
      path_lib.join(Directory.current.path, 'assets', 'putty'),
      // Hardcoded fallback for development
      'D:\\Flutter apps\\flutter_app\\assets\\attachments\\putty',
      // System paths
      'C:\\Program Files\\PuTTY',
      'C:\\Program Files (x86)\\PuTTY',
      // User paths
      '${Platform.environment['USERPROFILE']}\\AppData\\Local\\Programs\\PuTTY',
    ];

    for (final basePath in possibleBasePaths) {
      final plinkPath = path_lib.join(basePath, 'plink.exe');
      if (await File(plinkPath).exists()) {
        _plinkPath = plinkPath;
        _pscpPath = path_lib.join(basePath, 'pscp.exe');
        _psftpPath = path_lib.join(basePath, 'psftp.exe');
        _puttyPath = path_lib.join(basePath, 'putty.exe');
        _log('Found PuTTY tools at: $basePath', SshLogLevel.info);
        break;
      }
    }

    // Fallback to system PATH
    if (_plinkPath == null) {
      _plinkPath = 'plink';
      _pscpPath = 'pscp';
      _psftpPath = 'psftp';
      _puttyPath = 'putty';
      _log('Using PuTTY tools from system PATH', SshLogLevel.warning);
    }
  }

  // ============ Unit Selection ============
  void selectUnit(String unitType) {
    if (unitConfigs.containsKey(unitType)) {
      _selectedUnit = unitType;
      _log('Selected unit: $unitType', SshLogLevel.info);
      notifyListeners();
    }
  }

  // ============ Connection Methods ============

  /// Connect to NBT unit via SSH
  Future<bool> connect(String ip) async {
    if (_isConnecting) return false;

    _isConnecting = true;
    _connectionStatus = 'Connecting...';
    notifyListeners();

    _log('🔌 Connecting to $ip...', SshLogLevel.info);
    _log('Unit: $_selectedUnit | User: $currentUser', SshLogLevel.info);

    try {
      // Step 1: Accept host key first (required for first connection)
      await _acceptHostKey(ip);

      // Step 2: Test SSH connection with retry
      bool connected = false;
      for (int attempt = 1; attempt <= maxRetries && !connected; attempt++) {
        _log('Connection attempt $attempt/$maxRetries...', SshLogLevel.info);

        final result = await Process.run(
          _plinkPath!,
          [
            '-ssh',
            '-batch',
            '-pw',
            currentPassword,
            '$currentUser@$ip',
            'echo',
            'SSH_CONNECTED_OK'
          ],
          runInShell: true,
        ).timeout(connectionTimeout);

        final stdout = result.stdout.toString();
        final stderr = result.stderr.toString();

        if (stdout.contains('SSH_CONNECTED_OK')) {
          connected = true;
          _hostKeyAccepted = true;
          _log('✅ SSH connection established!', SshLogLevel.success);
        } else if (stderr.contains('host key') ||
            stderr.contains('fingerprint')) {
          // Host key issue - try to accept again
          _log('⚠️ Host key issue, re-accepting...', SshLogLevel.warning);
          await _acceptHostKey(ip);
        } else if (attempt < maxRetries) {
          _log('⚠️ Attempt $attempt failed, retrying...', SshLogLevel.warning);
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (connected) {
        _isConnected = true;
        _connectedIp = ip;
        _connectionStatus = 'Connected';

        // Auto mount filesystem
        await _mountFilesystem();

        // Check if SCP is installed
        await _checkScpInstalled();

        notifyListeners();
        return true;
      } else {
        _connectionStatus = 'Failed';
        _log('❌ Connection failed after $maxRetries attempts',
            SshLogLevel.error);
        notifyListeners();
        return false;
      }
    } on TimeoutException {
      _connectionStatus = 'Timeout';
      _log('❌ Connection timed out', SshLogLevel.error);
      notifyListeners();
      return false;
    } catch (e) {
      _connectionStatus = 'Error';
      _log('❌ Connection error: $e', SshLogLevel.error);
      notifyListeners();
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Accept SSH host key automatically using plink with multiple fallback methods
  /// This is critical for first-time connections to NBT units
  Future<bool> _acceptHostKey(String ip) async {
    _log('🔑 Accepting host key for $ip...', SshLogLevel.info);

    // Method 1: Use cmd /c echo y | plink (most reliable on Windows)
    try {
      final result = await Process.run(
        'cmd',
        [
          '/c',
          'echo',
          'y',
          '|',
          _plinkPath!,
          '-ssh',
          '-pw',
          currentPassword,
          '$currentUser@$ip',
          'exit'
        ],
        runInShell: true,
      ).timeout(const Duration(seconds: 15));

      final stderr = result.stderr.toString();
      final stdout = result.stdout.toString();

      // Check if key was accepted or already cached
      if (result.exitCode == 0 ||
          stderr.contains('Store key in cache') ||
          stdout.contains('exit') ||
          !stderr.contains('abandoned')) {
        _log('✅ Host key accepted (method 1)', SshLogLevel.success);
        _hostKeyAccepted = true;
        return true;
      }
    } catch (e) {
      _log('Method 1 host key: $e', SshLogLevel.warning);
    }

    // Method 2: Use PowerShell echo y | plink
    try {
      final psCommand =
          'echo y | & "${_plinkPath!}" -ssh -pw "$currentPassword" "$currentUser@$ip" exit';
      final result = await Process.run(
        'powershell',
        ['-Command', psCommand],
        runInShell: true,
      ).timeout(const Duration(seconds: 15));

      if (result.exitCode == 0) {
        _log('✅ Host key accepted (method 2)', SshLogLevel.success);
        _hostKeyAccepted = true;
        return true;
      }
    } catch (e) {
      _log('Method 2 host key: $e', SshLogLevel.warning);
    }

    // Method 3: Use batch file with redirection
    try {
      final tempDir = await Directory.systemTemp.createTemp('ssh_hostkey_');
      final batchFile = File(path_lib.join(tempDir.path, 'accept_key.bat'));
      await batchFile.writeAsString('''@echo off
echo y | "${_plinkPath!}" -ssh -pw "$currentPassword" "$currentUser@$ip" exit 2>nul
exit /b 0
''');

      await Process.run(
        batchFile.path,
        [],
        runInShell: true,
      ).timeout(const Duration(seconds: 15));

      await tempDir.delete(recursive: true);

      _log('✅ Host key accepted (method 3)', SshLogLevel.success);
      _hostKeyAccepted = true;
      return true;
    } catch (e) {
      _log('Method 3 host key: $e', SshLogLevel.warning);
    }

    _log('⚠️ Host key acceptance completed (status uncertain)',
        SshLogLevel.warning);
    return false;
  }

  /// Disconnect from NBT unit
  void disconnect() {
    _isConnected = false;
    _connectedIp = null;
    _connectionStatus = 'Disconnected';
    _log('🔌 Disconnected', SshLogLevel.info);
    notifyListeners();
  }

  /// Mount filesystem as read-write
  /// QNX filesystem is read-only by default, needs explicit mount
  Future<bool> _mountFilesystem() async {
    _log('📂 Mounting filesystem as RW...', SshLogLevel.info);

    // All possible mount points for QNX-based BMW units
    final commands = [
      // Primary sda0 mount (most common)
      'mount -uw /fs/sda0',
      // HU-OMAP path
      'mount -uw qnx6 /net/hu-omap/fs/sda0',
      // Root filesystem
      'mount -uw /',
      // Alternative root mount
      'mount -uw /mnt',
      // Repository mount
      'mount -uw /fs/sda0/repository',
      // ISTEP mount
      'mount -uw /fs/sda0/repository/istep',
    ];

    int successCount = 0;
    for (final cmd in commands) {
      try {
        final result = await executeCommand(cmd);
        if (!result.contains('error') && !result.contains('failed')) {
          successCount++;
        }
      } catch (_) {
        // Some mount commands may fail depending on unit type
      }
    }

    if (successCount > 0) {
      _log('✅ Filesystem mounted ($successCount mounts)', SshLogLevel.success);
    } else {
      _log('⚠️ Mount commands executed, some may not apply to this unit',
          SshLogLevel.warning);
    }
    return true;
  }

  /// Check if SCP binary is installed on the unit
  Future<bool> _checkScpInstalled() async {
    try {
      final result = await executeCommand('which scp');
      _scpInstalled =
          result.contains('/bin/scp') || result.contains('/usr/bin/scp');
      _log(_scpInstalled ? '✅ SCP is installed' : '⚠️ SCP not installed',
          _scpInstalled ? SshLogLevel.success : SshLogLevel.warning);
      notifyListeners();
      return _scpInstalled;
    } catch (_) {
      _scpInstalled = false;
      notifyListeners();
      return false;
    }
  }

  // ============ SCP Binary Installation ============

  /// Install SCP binary to NBT unit using SFTP
  /// This is required for faster file transfers on QNX-based units
  Future<bool> installScpBinary(String scpBinaryPath) async {
    if (!_isConnected || _connectedIp == null) {
      _log('❌ Not connected', SshLogLevel.error);
      return false;
    }

    if (!await File(scpBinaryPath).exists()) {
      _log('❌ SCP binary not found: $scpBinaryPath', SshLogLevel.error);
      return false;
    }

    _log('📦 Installing SCP binary...', SshLogLevel.info);
    _log('Step 1: Uploading via SFTP...', SshLogLevel.info);

    try {
      // Step 1: Upload using SFTP (more reliable than SCP for initial transfer)
      final uploaded = await uploadFileViaSftp(scpBinaryPath, '/tmp/scp');
      if (!uploaded) {
        _log('❌ Failed to upload SCP binary', SshLogLevel.error);
        return false;
      }

      _log('Step 2: Moving to /bin and setting permissions...',
          SshLogLevel.info);

      // Step 2: Move to /bin and set permissions
      await executeCommand('cp /tmp/scp /bin/scp');
      await executeCommand('chmod 755 /bin/scp');

      // Step 3: Verify installation
      _log('Step 3: Verifying installation...', SshLogLevel.info);
      final verified = await _checkScpInstalled();

      if (verified) {
        _log('✅ SCP binary installed successfully!', SshLogLevel.success);
        return true;
      } else {
        _log('⚠️ SCP installation may have failed', SshLogLevel.warning);
        return false;
      }
    } catch (e) {
      _log('❌ Installation error: $e', SshLogLevel.error);
      return false;
    }
  }

  // ============ File Transfer Methods ============

  /// Upload file using the best available protocol
  /// Tries multiple protocols with retry logic for reliability
  Future<bool> uploadFile(
    String localPath,
    String remotePath, {
    Function(double)? onProgress,
  }) async {
    if (!_isConnected || _connectedIp == null) {
      _log('❌ Not connected', SshLogLevel.error);
      return false;
    }

    final localFile = File(localPath);
    if (!await localFile.exists()) {
      _log('❌ Local file not found: $localPath', SshLogLevel.error);
      return false;
    }

    final fileSize = await localFile.length();
    final fileName = path_lib.basename(localPath);
    _log('📤 Uploading: $fileName (${_formatBytes(fileSize)})',
        SshLogLevel.info);

    // Ensure remote directory exists
    final remoteDir = path_lib.dirname(remotePath).replaceAll('\\', '/');
    try {
      await executeCommand('mkdir -p "$remoteDir"');
    } catch (_) {
      // Directory might already exist
    }

    // Try upload with multiple protocols and retries
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      _log('Upload attempt $attempt/$maxRetries...', SshLogLevel.info);

      // Protocol 1: PSCP with SFTP mode (most reliable for QNX)
      _log('Trying PSCP (SFTP mode)...', SshLogLevel.info);
      if (await _uploadViaPscpSftp(localPath, remotePath)) {
        _log('✅ Upload successful on attempt $attempt', SshLogLevel.success);
        return true;
      }

      // Protocol 2: PSCP with SCP mode
      _log('Trying PSCP (SCP mode)...', SshLogLevel.info);
      if (await _uploadViaPscpScp(localPath, remotePath)) {
        _log('✅ Upload successful on attempt $attempt', SshLogLevel.success);
        return true;
      }

      // Protocol 3: PSFTP batch mode
      _log('Trying PSFTP batch mode...', SshLogLevel.info);
      if (await uploadFileViaSftp(localPath, remotePath)) {
        _log('✅ Upload successful on attempt $attempt', SshLogLevel.success);
        return true;
      }

      // Protocol 4: SSH Piping (cat over SSH tunnel - for QNX without scp)
      _log('Trying SSH Piping method...', SshLogLevel.info);
      if (await _uploadViaSshPiping(localPath, remotePath)) {
        _log('✅ Upload successful via SSH Piping', SshLogLevel.success);
        return true;
      }

      // Protocol 5: Netcat transfer (if nc is available)
      _log('Trying Netcat transfer...', SshLogLevel.info);
      if (await _uploadViaNetcat(localPath, remotePath)) {
        _log('✅ Upload successful via Netcat', SshLogLevel.success);
        return true;
      }

      // Protocol 6: Base64 encoded transfer (final fallback)
      if (attempt == maxRetries) {
        _log('Trying base64 transfer (final fallback)...', SshLogLevel.info);
        if (await _uploadViaBase64(localPath, remotePath)) {
          _log('✅ Upload successful via base64', SshLogLevel.success);
          return true;
        }
      }

      if (attempt < maxRetries) {
        _log('⚠️ Upload attempt $attempt failed, retrying...',
            SshLogLevel.warning);
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    _log('❌ Upload failed after $maxRetries attempts', SshLogLevel.error);
    return false;
  }

  /// Upload entire directory recursively
  /// Creates remote directory structure and uploads all files
  Future<DirectoryUploadResult> uploadDirectory(
    String localDirPath,
    String remoteDirPath, {
    void Function(int current, int total, String filename)? onProgress,
  }) async {
    if (!_isConnected || _connectedIp == null) {
      return DirectoryUploadResult(
          success: false, uploaded: 0, failed: 0, message: 'Not connected');
    }

    final dir = Directory(localDirPath);
    if (!await dir.exists()) {
      return DirectoryUploadResult(
          success: false,
          uploaded: 0,
          failed: 0,
          message: 'Directory not found');
    }

    _log('📂 Uploading directory: ${path_lib.basename(localDirPath)}',
        SshLogLevel.info);
    _log('To: $remoteDirPath', SshLogLevel.info);

    // Create remote directory
    await executeCommand('mkdir -p "$remoteDirPath"');

    // Collect all files
    final files = <FileSystemEntity>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }

    _log('Found ${files.length} files to upload', SshLogLevel.info);

    int uploaded = 0;
    int failed = 0;
    final List<String> failedFiles = [];

    for (int i = 0; i < files.length; i++) {
      final file = files[i] as File;
      final relativePath = path_lib.relative(file.path, from: localDirPath);
      final remoteFilePath =
          '$remoteDirPath/${relativePath.replaceAll('\\', '/')}';

      // Create parent directory on remote
      final remoteParent = path_lib.dirname(remoteFilePath);
      await executeCommand('mkdir -p "$remoteParent"');

      // Upload file
      final success = await uploadFile(file.path, remoteFilePath);

      if (success) {
        uploaded++;
      } else {
        failed++;
        failedFiles.add(relativePath);
      }

      onProgress?.call(i + 1, files.length, path_lib.basename(file.path));
    }

    final message = 'Uploaded $uploaded/${files.length} files';
    if (failed > 0) {
      _log('⚠️ $message ($failed failed)', SshLogLevel.warning);
    } else {
      _log('✅ $message', SshLogLevel.success);
    }

    return DirectoryUploadResult(
      success: failed == 0,
      uploaded: uploaded,
      failed: failed,
      message: message,
      failedFiles: failedFiles,
    );
  }

  /// Download entire directory recursively
  Future<DirectoryUploadResult> downloadDirectory(
    String remoteDirPath,
    String localDirPath, {
    void Function(int current, int total, String filename)? onProgress,
  }) async {
    if (!_isConnected || _connectedIp == null) {
      return DirectoryUploadResult(
          success: false, uploaded: 0, failed: 0, message: 'Not connected');
    }

    _log('📂 Downloading directory: $remoteDirPath', SshLogLevel.info);
    _log('To: $localDirPath', SshLogLevel.info);

    // Create local directory
    await Directory(localDirPath).create(recursive: true);

    // List remote files
    final listResult =
        await executeCommand('find "$remoteDirPath" -type f 2>/dev/null');
    if (listResult.isEmpty || listResult.contains('No such file')) {
      return DirectoryUploadResult(
          success: false,
          uploaded: 0,
          failed: 0,
          message: 'Remote directory not found or empty');
    }

    final remoteFiles =
        listResult.split('\n').where((f) => f.trim().isNotEmpty).toList();

    _log('Found ${remoteFiles.length} files to download', SshLogLevel.info);

    int downloaded = 0;
    int failed = 0;

    for (int i = 0; i < remoteFiles.length; i++) {
      final remoteFile = remoteFiles[i].trim();
      if (remoteFile.isEmpty) continue;

      // Calculate local path
      String relativePath = remoteFile.startsWith(remoteDirPath)
          ? remoteFile.substring(remoteDirPath.length)
          : path_lib.basename(remoteFile);
      if (relativePath.startsWith('/')) {
        relativePath = relativePath.substring(1);
      }

      final localFilePath = path_lib.join(localDirPath, relativePath);

      // Create parent directory
      await Directory(path_lib.dirname(localFilePath)).create(recursive: true);

      // Download
      final success = await downloadFile(remoteFile, localFilePath);
      if (success) {
        downloaded++;
      } else {
        failed++;
      }

      onProgress?.call(
          i + 1, remoteFiles.length, path_lib.basename(remoteFile));
    }

    final message = 'Downloaded $downloaded/${remoteFiles.length} files';
    _log(failed > 0 ? '⚠️ $message' : '✅ $message',
        failed > 0 ? SshLogLevel.warning : SshLogLevel.success);

    return DirectoryUploadResult(
      success: failed == 0,
      uploaded: downloaded,
      failed: failed,
      message: message,
    );
  }

  /// Upload file using PSCP with SFTP protocol (most reliable)
  /// Uses echo y | to auto-accept host key if needed
  Future<bool> _uploadViaPscpSftp(String localPath, String remotePath) async {
    try {
      // First, ensure host key is accepted using echo y | pscp
      // This is the most reliable method for automated file transfers
      await Process.run(
        'cmd',
        [
          '/c',
          'echo',
          'y',
          '|',
          _pscpPath!,
          '-sftp',
          '-pw',
          currentPassword,
          '-ls',
          '$currentUser@$_connectedIp:/'
        ],
        runInShell: true,
      ).timeout(const Duration(seconds: 15));

      // Small delay to ensure key is cached
      await Future.delayed(const Duration(milliseconds: 500));

      // Now perform actual upload with -batch flag
      final result = await Process.run(
        _pscpPath!,
        [
          '-sftp', // Force SFTP protocol
          '-batch',
          '-pw',
          currentPassword,
          '-l',
          currentUser,
          localPath,
          '$currentUser@$_connectedIp:$remotePath'
        ],
        runInShell: true,
      ).timeout(uploadTimeout);

      final exitCode = result.exitCode;
      final stderr = result.stderr.toString();
      final stdout = result.stdout.toString();

      // Check multiple success indicators
      if (exitCode == 0 ||
          stdout.contains('100%') ||
          !stderr.contains('FATAL')) {
        final verified = await _verifyUpload(remotePath);
        if (verified) return true;
      }

      _log('PSCP SFTP stderr: $stderr', SshLogLevel.warning);
      return false;
    } catch (e) {
      _log('PSCP SFTP exception: $e', SshLogLevel.warning);
      return false;
    }
  }

  /// Upload file using PSCP with SCP protocol
  /// Uses echo y | to auto-accept host key if needed
  Future<bool> _uploadViaPscpScp(String localPath, String remotePath) async {
    try {
      // First, ensure host key is accepted
      await Process.run(
        'cmd',
        [
          '/c',
          'echo',
          'y',
          '|',
          _pscpPath!,
          '-scp',
          '-pw',
          currentPassword,
          '-ls',
          '$currentUser@$_connectedIp:/'
        ],
        runInShell: true,
      ).timeout(const Duration(seconds: 15));

      await Future.delayed(const Duration(milliseconds: 500));

      // Perform actual upload
      final result = await Process.run(
        _pscpPath!,
        [
          '-scp', // Force SCP protocol
          '-batch',
          '-pw',
          currentPassword,
          localPath,
          '$currentUser@$_connectedIp:$remotePath'
        ],
        runInShell: true,
      ).timeout(uploadTimeout);

      final exitCode = result.exitCode;
      final stderr = result.stderr.toString();
      final stdout = result.stdout.toString();

      if (exitCode == 0 ||
          stdout.contains('100%') ||
          !stderr.contains('FATAL')) {
        final verified = await _verifyUpload(remotePath);
        if (verified) return true;
      }

      _log('PSCP SCP stderr: $stderr', SshLogLevel.warning);
      return false;
    } catch (e) {
      _log('PSCP SCP exception: $e', SshLogLevel.warning);
      return false;
    }
  }

  /// Upload file via base64 encoding (fallback for problematic connections)
  /// This method is slower but more reliable for some embedded systems
  Future<bool> _uploadViaBase64(String localPath, String remotePath) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      // Split into chunks (QNX command line limit)
      const chunkSize = 4096;
      final chunks = <String>[];
      for (int i = 0; i < base64Data.length; i += chunkSize) {
        final end = (i + chunkSize > base64Data.length)
            ? base64Data.length
            : i + chunkSize;
        chunks.add(base64Data.substring(i, end));
      }

      _log('Uploading ${chunks.length} chunks via base64...', SshLogLevel.info);

      // Clear target file first
      await executeCommand('rm -f "$remotePath"');

      // Write chunks
      for (int i = 0; i < chunks.length; i++) {
        final operator = i == 0 ? '>' : '>>';
        await executeCommand('echo "${chunks[i]}" $operator "$remotePath.b64"');
      }

      // Decode on target
      await executeCommand('cat "$remotePath.b64" | base64 -d > "$remotePath"');
      await executeCommand('rm -f "$remotePath.b64"');

      return await _verifyUpload(remotePath);
    } catch (e) {
      _log('Base64 upload exception: $e', SshLogLevel.error);
      return false;
    }
  }

  /// Upload file via SSH Piping (cat over SSH tunnel)
  /// This is the most reliable method for QNX systems without scp/sftp
  /// Uses: type local_file | ssh root@ip "cat > /remote/path"
  Future<bool> _uploadViaSshPiping(String localPath, String remotePath) async {
    if (!_isConnected || _connectedIp == null) return false;

    try {
      _log('Trying SSH Piping method...', SshLogLevel.info);

      final file = File(localPath);
      if (!await file.exists()) return false;

      // First accept host key
      await _acceptHostKey(_connectedIp!);

      // Create remote directory
      await executeCommand(
          'mkdir -p "${path_lib.dirname(remotePath).replaceAll('\\', '/')}"');

      // Use PowerShell to pipe file content through SSH
      // cmd: type local_file | plink -ssh -batch -pw password user@ip "cat > /remote/path"
      final psCommand = '''
\$content = [System.IO.File]::ReadAllBytes("$localPath")
\$base64 = [Convert]::ToBase64String(\$content)
echo \$base64 | & "${_plinkPath!}" -ssh -batch -pw "$currentPassword" "$currentUser@$_connectedIp" "cat | base64 -d > \\"$remotePath\\""
''';

      final result = await Process.run(
        'powershell',
        ['-Command', psCommand],
        runInShell: true,
      ).timeout(uploadTimeout);

      if (result.exitCode == 0) {
        return await _verifyUpload(remotePath);
      }

      // Alternative method using direct binary piping
      _log('Trying alternative piping method...', SshLogLevel.info);

      final tempDir = await Directory.systemTemp.createTemp('ssh_pipe_');
      final batchFile = File(path_lib.join(tempDir.path, 'upload.ps1'));

      await batchFile.writeAsString('''
\$bytes = [System.IO.File]::ReadAllBytes("$localPath")
\$process = Start-Process -FilePath "${_plinkPath!}" -ArgumentList @(
    "-ssh", "-batch", "-pw", "$currentPassword",
    "$currentUser@$_connectedIp",
    "cat > `"$remotePath`""
) -NoNewWindow -PassThru -RedirectStandardInput pipe
\$process.StandardInput.BaseStream.Write(\$bytes, 0, \$bytes.Length)
\$process.StandardInput.Close()
\$process.WaitForExit()
exit \$process.ExitCode
''');

      final altResult = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-File', batchFile.path],
        runInShell: true,
      ).timeout(uploadTimeout);

      await tempDir.delete(recursive: true);

      if (altResult.exitCode == 0) {
        return await _verifyUpload(remotePath);
      }

      return false;
    } catch (e) {
      _log('SSH Piping exception: $e', SshLogLevel.warning);
      return false;
    }
  }

  /// Upload file via Netcat (nc) if available on the unit
  /// This is useful when neither SCP nor SFTP is available
  /// Step 1: Start nc listener on unit: nc -l -p PORT > /path
  /// Step 2: Send file from PC: nc IP PORT < local_file
  Future<bool> _uploadViaNetcat(String localPath, String remotePath,
      {int port = 12345}) async {
    if (!_isConnected || _connectedIp == null) return false;

    try {
      _log('Trying Netcat transfer method...', SshLogLevel.info);

      // Check if nc is available on the unit
      final ncCheck = await executeCommand('which nc');
      if (!ncCheck.contains('/nc') && !ncCheck.contains('nc')) {
        _log('Netcat (nc) not available on unit', SshLogLevel.warning);
        return false;
      }

      // Create remote directory
      await executeCommand(
          'mkdir -p "${path_lib.dirname(remotePath).replaceAll('\\', '/')}"');

      // Start nc listener on the unit in background
      // The listener will write to the target file
      final ncCommand = 'nc -l -p $port > "$remotePath" &';
      await executeCommand(ncCommand);

      // Small delay to let nc start
      await Future.delayed(const Duration(seconds: 1));

      // Send file using PowerShell's TCP client
      final psScript = '''
try {
    \$client = New-Object System.Net.Sockets.TcpClient("$_connectedIp", $port)
    \$stream = \$client.GetStream()
    \$bytes = [System.IO.File]::ReadAllBytes("$localPath")
    \$stream.Write(\$bytes, 0, \$bytes.Length)
    \$stream.Close()
    \$client.Close()
    exit 0
} catch {
    Write-Error \$_
    exit 1
}
''';

      final result = await Process.run(
        'powershell',
        ['-Command', psScript],
        runInShell: true,
      ).timeout(const Duration(seconds: 30));

      if (result.exitCode == 0) {
        // Verify the upload
        return await _verifyUpload(remotePath);
      }

      _log('Netcat transfer failed: ${result.stderr}', SshLogLevel.warning);
      return false;
    } catch (e) {
      _log('Netcat exception: $e', SshLogLevel.warning);
      return false;
    }
  }

  /// Verify file was uploaded correctly
  Future<bool> _verifyUpload(String remotePath) async {
    try {
      final result = await executeCommand('ls -la "$remotePath"');
      if (result.isNotEmpty && !result.contains('No such file')) {
        _log('✅ File verified on remote', SshLogLevel.success);
        return true;
      }
      _log('⚠️ File verification failed', SshLogLevel.warning);
      return false;
    } catch (e) {
      _log('Verification error: $e', SshLogLevel.warning);
      return false;
    }
  }

  /// Upload file using PSCP (PuTTY Secure Copy) - Legacy method
  /// Uses echo y | to accept host key automatically
  Future<bool> uploadFileViaPscp(String localPath, String remotePath) async {
    try {
      // Accept host key first
      await Process.run(
        'cmd',
        [
          '/c',
          'echo',
          'y',
          '|',
          _pscpPath!,
          '-pw',
          currentPassword,
          '-ls',
          '$currentUser@$_connectedIp:/'
        ],
        runInShell: true,
      ).timeout(const Duration(seconds: 15));

      await Future.delayed(const Duration(milliseconds: 500));

      final result = await Process.run(
        _pscpPath!,
        [
          '-batch',
          '-pw',
          currentPassword,
          localPath,
          '$currentUser@$_connectedIp:"$remotePath"'
        ],
        runInShell: true,
      ).timeout(const Duration(minutes: 5));

      if (result.exitCode == 0) {
        _log('✅ PSCP upload successful', SshLogLevel.success);
        return true;
      } else {
        _log('❌ PSCP error: ${result.stderr}', SshLogLevel.error);
        return false;
      }
    } catch (e) {
      _log('❌ PSCP exception: $e', SshLogLevel.error);
      return false;
    }
  }

  /// Upload file using SFTP (SSH File Transfer Protocol)
  /// Uses echo y | psftp to accept host key before batch mode
  Future<bool> uploadFileViaSftp(String localPath, String remotePath) async {
    try {
      // First, accept host key using echo y | psftp
      await Process.run(
        'cmd',
        [
          '/c',
          'echo',
          'y',
          '|',
          _psftpPath!,
          '-pw',
          currentPassword,
          '$currentUser@$_connectedIp'
        ],
        runInShell: true,
      ).timeout(const Duration(seconds: 10));

      await Future.delayed(const Duration(milliseconds: 500));

      // Create batch file for SFTP commands
      final tempDir = await Directory.systemTemp.createTemp('sftp_');
      final batchFile = File(path_lib.join(tempDir.path, 'sftp_batch.txt'));

      final remoteDir = path_lib.dirname(remotePath).replaceAll('\\', '/');
      final remoteFileName = path_lib.basename(remotePath);

      // Use proper SFTP commands with mkdir (ignore errors if exists)
      final sftpCommands = '''
mkdir "$remoteDir"
cd "$remoteDir"
put "$localPath" "$remoteFileName"
quit
''';

      await batchFile.writeAsString(sftpCommands);

      final result = await Process.run(
        _psftpPath!,
        [
          '-batch',
          '-be', // Continue on errors (like mkdir if dir exists)
          '-b',
          batchFile.path,
          '-pw',
          currentPassword,
          '$currentUser@$_connectedIp'
        ],
        runInShell: true,
      ).timeout(uploadTimeout);

      // Cleanup
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}

      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();

      // Check for success indicators
      if (result.exitCode == 0 ||
          stdout.contains('local:') ||
          stdout.contains('remote:')) {
        return await _verifyUpload(remotePath);
      } else {
        _log('SFTP stderr: $stderr', SshLogLevel.warning);
        return false;
      }
    } catch (e) {
      _log('SFTP exception: $e', SshLogLevel.warning);
      return false;
    }
  }

  /// Upload file using native SCP on the unit
  Future<bool> uploadFileViaScp(String localPath, String remotePath) async {
    // For native SCP, we need to use a reverse approach
    // First upload to /tmp via PSCP, then use unit's scp/cp to move
    try {
      final fileName = path_lib.basename(localPath);
      final tempRemotePath = '/tmp/$fileName';

      // Upload to /tmp first
      final uploaded = await uploadFileViaPscp(localPath, tempRemotePath);
      if (!uploaded) return false;

      // Move to final destination
      await executeCommand('cp "$tempRemotePath" "$remotePath"');
      await executeCommand('rm "$tempRemotePath"');

      _log('✅ Native SCP transfer successful', SshLogLevel.success);
      return true;
    } catch (e) {
      _log('❌ Native SCP exception: $e', SshLogLevel.error);
      return false;
    }
  }

  /// Download file from unit with retry logic
  /// Includes host key auto-acceptance for reliable transfers
  Future<bool> downloadFile(String remotePath, String localPath) async {
    if (!_isConnected || _connectedIp == null) {
      _log('❌ Not connected', SshLogLevel.error);
      return false;
    }

    _log('📥 Downloading: ${path_lib.basename(remotePath)}', SshLogLevel.info);

    // Accept host key before download attempts
    await Process.run(
      'cmd',
      [
        '/c',
        'echo',
        'y',
        '|',
        _pscpPath!,
        '-sftp',
        '-pw',
        currentPassword,
        '-ls',
        '$currentUser@$_connectedIp:/'
      ],
      runInShell: true,
    ).timeout(const Duration(seconds: 10));

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Try PSCP with SFTP mode first (most reliable for QNX)
        var result = await Process.run(
          _pscpPath!,
          [
            '-sftp',
            '-batch',
            '-pw',
            currentPassword,
            '$currentUser@$_connectedIp:$remotePath',
            localPath
          ],
          runInShell: true,
        ).timeout(uploadTimeout);

        if (result.exitCode == 0 && await File(localPath).exists()) {
          _log('✅ Download successful', SshLogLevel.success);
          return true;
        }

        // Try SCP mode
        result = await Process.run(
          _pscpPath!,
          [
            '-scp',
            '-batch',
            '-pw',
            currentPassword,
            '$currentUser@$_connectedIp:$remotePath',
            localPath
          ],
          runInShell: true,
        ).timeout(uploadTimeout);

        if (result.exitCode == 0 && await File(localPath).exists()) {
          _log('✅ Download successful', SshLogLevel.success);
          return true;
        }

        if (attempt < maxRetries) {
          _log('⚠️ Download attempt $attempt failed, retrying...',
              SshLogLevel.warning);
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        _log('Download exception: $e', SshLogLevel.warning);
      }
    }

    _log('❌ Download failed after $maxRetries attempts', SshLogLevel.error);
    return false;
  }

  // ============ Command Execution ============

  /// Execute SSH command on the unit
  Future<String> executeCommand(String command) async {
    if (!_isConnected || _connectedIp == null) {
      throw Exception('Not connected');
    }

    _log('> $command', SshLogLevel.command);

    final result = await Process.run(
      _plinkPath!,
      [
        '-ssh',
        '-batch',
        '-pw',
        currentPassword,
        '$currentUser@$_connectedIp',
        command
      ],
      runInShell: true,
    ).timeout(const Duration(seconds: 30));

    final output = result.stdout.toString().trim();
    if (output.isNotEmpty) {
      _log(output, SshLogLevel.output);
    }

    if (result.stderr.toString().trim().isNotEmpty) {
      _log(result.stderr.toString().trim(), SshLogLevel.warning);
    }

    return output;
  }

  // ============ Image Operations ============

  /// Upload hero image for vehicle model
  Future<bool> uploadHeroImage(
      String localPath, String model, String brand) async {
    if (!['bmw', 'bmwm', 'rr'].contains(brand)) {
      _log('❌ Invalid brand: $brand', SshLogLevel.error);
      return false;
    }

    // Determine filename based on model series
    String filename;
    if (model.toUpperCase().startsWith('G')) {
      filename = 'id6_main_${model.toLowerCase()}_hero.png';
    } else {
      filename = 'id6hero_${model.toLowerCase()}.png';
    }

    final pathTemplate =
        (imagePaths['Hero Image'] as Map<String, String>)[brand]!;
    final basePath = pathTemplate.replaceAll('{model}', model.toUpperCase());
    final remotePath = '$basePath/$filename';

    _log('📷 Uploading hero image for $brand $model', SshLogLevel.info);
    _log('Remote path: $remotePath', SshLogLevel.info);

    // Create backup first
    await _backupFile(remotePath);

    return await uploadFile(localPath, remotePath);
  }

  /// Upload clock background image
  Future<bool> uploadClockBackground(String localPath, String clockType) async {
    final clockPaths = imagePaths['Clock Background'] as Map<String, String>;
    if (!clockPaths.containsKey(clockType)) {
      _log('❌ Invalid clock type: $clockType', SshLogLevel.error);
      return false;
    }

    final filename = clockPaths[clockType]!;
    final basePath = clockPaths['basePath']!;
    final remotePath = '$basePath$filename';

    _log('🕐 Uploading clock background: $clockType', SshLogLevel.info);

    await _backupFile(remotePath);
    return await uploadFile(localPath, remotePath);
  }

  /// Upload boot animation
  Future<bool> uploadBootAnimation(String localPath) async {
    final remotePath = imagePaths['Boot Animation'] as String;

    _log('🎬 Uploading boot animation...', SshLogLevel.info);

    await _backupFile(remotePath);
    return await uploadFile(localPath, remotePath);
  }

  /// Upload logo
  Future<bool> uploadLogo(String localPath, String logoType) async {
    final logoPaths = imagePaths['Logo'] as Map<String, String>;
    if (!logoPaths.containsKey(logoType)) {
      _log('❌ Invalid logo type: $logoType', SshLogLevel.error);
      return false;
    }

    final remotePath = logoPaths[logoType]!;

    _log('🏷️ Uploading $logoType logo...', SshLogLevel.info);

    await _backupFile(remotePath);
    return await uploadFile(localPath, remotePath);
  }

  /// Backup file before replacing
  Future<void> _backupFile(String remotePath) async {
    try {
      await executeCommand(
          "if [ -f '$remotePath' ]; then cp '$remotePath' '$remotePath.back'; fi");
      _log('📦 Backup created: ${path_lib.basename(remotePath)}.back',
          SshLogLevel.info);
    } catch (_) {
      _log('⚠️ Could not create backup', SshLogLevel.warning);
    }
  }

  /// Restore file from backup
  Future<bool> restoreBackup(String remotePath) async {
    try {
      await executeCommand(
          "if [ -f '$remotePath.back' ]; then cp '$remotePath.back' '$remotePath'; fi");
      _log('✅ Restored from backup', SshLogLevel.success);
      return true;
    } catch (e) {
      _log('❌ Restore failed: $e', SshLogLevel.error);
      return false;
    }
  }

  // ============ Unit Control ============

  /// Reboot the head unit
  Future<void> rebootUnit() async {
    _log('🔄 Rebooting head unit...', SshLogLevel.info);
    try {
      await executeCommand('reboot');
      disconnect();
      _log('✅ Reboot command sent', SshLogLevel.success);
    } catch (_) {
      // Reboot may cause connection to drop before response
      disconnect();
      _log('✅ Reboot initiated', SshLogLevel.success);
    }
  }

  /// Mount filesystem as read-write
  Future<void> mountReadWrite() async {
    await executeCommand('mount -uw /fs/sda0');
    _log('✅ Filesystem mounted as read-write', SshLogLevel.success);
  }

  /// Mount filesystem as read-only
  Future<void> mountReadOnly() async {
    await executeCommand('mount -ur /fs/sda0');
    _log('✅ Filesystem mounted as read-only', SshLogLevel.success);
  }

  /// List USB contents
  Future<String> listUsb() async {
    return await executeCommand('ls -la /fs/usb0');
  }

  // ============ Logging ============

  void _log(String message, SshLogLevel level) {
    final entry = SshLogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );
    _logs.add(entry);

    // Keep only last 500 logs
    if (_logs.length > 500) {
      _logs.removeRange(0, _logs.length - 500);
    }

    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  // ============ Utilities ============

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get remote path for image type
  String? getRemotePath({
    required String imageType,
    String? model,
    String? brand,
    String? clockType,
    String? logoType,
  }) {
    switch (imageType) {
      case 'Hero Image':
        if (model == null || brand == null) return null;
        final pathTemplate =
            (imagePaths['Hero Image'] as Map<String, String>)[brand];
        if (pathTemplate == null) return null;
        final basePath =
            pathTemplate.replaceAll('{model}', model.toUpperCase());
        String filename;
        if (model.toUpperCase().startsWith('G')) {
          filename = 'id6_main_${model.toLowerCase()}_hero.png';
        } else {
          filename = 'id6hero_${model.toLowerCase()}.png';
        }
        return '$basePath/$filename';

      case 'Clock Background':
        if (clockType == null) return null;
        final clockPaths =
            imagePaths['Clock Background'] as Map<String, String>;
        final filename = clockPaths[clockType];
        if (filename == null) return null;
        return '${clockPaths['basePath']}$filename';

      case 'Boot Animation':
        return imagePaths['Boot Animation'] as String;

      case 'Logo':
        if (logoType == null) return null;
        return (imagePaths['Logo'] as Map<String, String>)[logoType];

      default:
        return null;
    }
  }
}

// ============ Log Entry Model ============

enum SshLogLevel {
  info,
  success,
  warning,
  error,
  command,
  output,
}

class SshLogEntry {
  final String message;
  final SshLogLevel level;
  final DateTime timestamp;

  SshLogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  String get formattedTime => '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';
}

// ============ Directory Upload Result ============

class DirectoryUploadResult {
  final bool success;
  final int uploaded;
  final int failed;
  final String message;
  final List<String> failedFiles;

  DirectoryUploadResult({
    required this.success,
    required this.uploaded,
    required this.failed,
    required this.message,
    this.failedFiles = const [],
  });
}
