import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'http_client_service.dart';

/// Auto Update Service for checking and downloading updates from GitHub releases
/// Uses HttpClientService for robust SSL handling on Windows
class AutoUpdateService extends ChangeNotifier {
  // GitHub repository info
  static const String _githubOwner = 'tiraUnderCode23';
  static const String _githubRepo = 'AQ-CheatsTool-Releases';
  static const String _githubApiUrl = 'https://api.github.com/repos';

  // Current app version
  static const String currentVersion = '3.2.0';
  static const int currentBuildNumber = 1;

  // Background check interval (check every 4 hours)
  static const Duration _backgroundCheckInterval = Duration(hours: 4);

  // Auto-download setting key
  static const String _autoDownloadKey = 'auto_download_updates';
  static const String _lastCheckKey = 'last_update_check';

  // Singleton
  static final AutoUpdateService _instance = AutoUpdateService._internal();
  factory AutoUpdateService() => _instance;
  AutoUpdateService._internal();

  // Background timer
  Timer? _backgroundCheckTimer;

  // State
  bool _isChecking = false;
  bool _isDownloading = false;
  bool _updateAvailable = false;
  bool _downloadComplete = false;
  double _downloadProgress = 0.0;
  String? _latestVersion;
  String? _downloadUrl;
  String? _releaseNotes;
  String? _downloadedFilePath;
  String? _error;
  bool _autoDownloadEnabled = true;

  // Getters
  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  bool get updateAvailable => _updateAvailable;
  bool get downloadComplete => _downloadComplete;
  double get downloadProgress => _downloadProgress;
  String? get latestVersion => _latestVersion;
  String? get releaseNotes => _releaseNotes;
  String? get error => _error;
  String? get downloadedFilePath => _downloadedFilePath;
  bool get autoDownloadEnabled => _autoDownloadEnabled;

  /// Initialize the service and start background checking
  Future<void> initialize() async {
    await _loadSettings();
    _startBackgroundChecking();
    debugPrint('[Update] Service initialized with background checking');
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoDownloadEnabled = prefs.getBool(_autoDownloadKey) ?? true;
    } catch (e) {
      debugPrint('[Update] Error loading settings: $e');
    }
  }

  /// Set auto-download preference
  Future<void> setAutoDownload(bool enabled) async {
    _autoDownloadEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoDownloadKey, enabled);
    } catch (e) {
      debugPrint('[Update] Error saving auto-download setting: $e');
    }
    notifyListeners();
  }

  /// Start background update checking
  void _startBackgroundChecking() {
    // Cancel existing timer if any
    _backgroundCheckTimer?.cancel();

    // Start periodic checking
    _backgroundCheckTimer =
        Timer.periodic(_backgroundCheckInterval, (timer) async {
      debugPrint('[Update] Background check triggered');
      await checkForUpdates(background: true);
    });

    debugPrint(
        '[Update] Background checking started (every ${_backgroundCheckInterval.inHours} hours)');
  }

  /// Stop background checking
  void stopBackgroundChecking() {
    _backgroundCheckTimer?.cancel();
    _backgroundCheckTimer = null;
    debugPrint('[Update] Background checking stopped');
  }

  /// Check for updates from GitHub releases
  /// Uses HttpClientService for robust SSL handling
  Future<bool> checkForUpdates({bool background = false}) async {
    if (_isChecking) return false;

    _isChecking = true;
    _error = null;
    if (!background) notifyListeners();

    try {
      // Check internet connectivity first
      if (!await HttpClientService.hasInternetConnection()) {
        debugPrint('[Update] No internet connection');
        _error = 'No internet connection';
        _isChecking = false;
        if (!background) notifyListeners();
        return false;
      }

      const url = '$_githubApiUrl/$_githubOwner/$_githubRepo/releases/latest';
      debugPrint('[Update] Checking: $url');

      final response = await HttpClientService.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'AQ-CheatsTool/$currentVersion',
        },
        timeout: const Duration(seconds: 30),
      );

      if (response == null) {
        debugPrint('[Update] No response from GitHub API');
        _error = 'Unable to connect to update server';
        _isChecking = false;
        if (!background) notifyListeners();
        return false;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String? ?? '';
        final latestVer = tagName.replaceAll('v', '').trim();

        debugPrint('[Update] Current: $currentVersion, Latest: $latestVer');

        _latestVersion = latestVer;
        _releaseNotes = data['body'] as String?;

        // Find Windows exe download URL
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.exe') || name.endsWith('.msix')) {
            _downloadUrl = asset['browser_download_url'] as String?;
            debugPrint('[Update] Download URL: $_downloadUrl');
            break;
          }
        }

        // Check if this version was skipped
        final skipped = await isVersionSkipped(latestVer);

        // Compare versions
        if (_isNewerVersion(latestVer, currentVersion) && !skipped) {
          _updateAvailable = true;
          debugPrint('[Update] Update available: $latestVer');

          // Auto-download if enabled and this is a background check
          if (background && _autoDownloadEnabled && _downloadUrl != null) {
            debugPrint('[Update] Auto-downloading update...');
            await downloadUpdate();
          }
        } else {
          _updateAvailable = false;
          debugPrint('[Update] App is up to date');
        }

        // Save last check time
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
              _lastCheckKey, DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}

        _isChecking = false;
        notifyListeners();
        return _updateAvailable;
      } else if (response.statusCode == 404) {
        // No releases yet
        debugPrint('[Update] No releases found');
        _updateAvailable = false;
        _isChecking = false;
        if (!background) notifyListeners();
        return false;
      } else if (response.statusCode == 403) {
        // Rate limited
        debugPrint('[Update] GitHub API rate limited');
        _error = 'Update check rate limited. Try again later.';
        _isChecking = false;
        if (!background) notifyListeners();
        return false;
      } else {
        throw Exception('GitHub API error: ${response.statusCode}');
      }
    } on TimeoutException {
      debugPrint('[Update] Update check timed out');
      _error = 'Connection timed out';
      _isChecking = false;
      if (!background) notifyListeners();
      return false;
    } on SocketException catch (e) {
      debugPrint('[Update] Network error: $e');
      _error = 'Network error. Please check your connection.';
      _isChecking = false;
      if (!background) notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[Update] Error checking updates: $e');
      _error = e.toString();
      _isChecking = false;
      if (!background) notifyListeners();
      return false;
    }
  }

  /// Compare version strings (e.g., "2.1.0" > "2.0.0")
  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (latestParts.length < 3) {
        latestParts.add(0);
      }
      while (currentParts.length < 3) {
        currentParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('[Update] Version compare error: $e');
      return false;
    }
  }

  /// Download the update file using HttpClientService
  Future<bool> downloadUpdate() async {
    if (_downloadUrl == null || _isDownloading) return false;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadComplete = false;
    _error = null;
    notifyListeners();

    try {
      // Check internet connectivity
      if (!await HttpClientService.hasInternetConnection()) {
        throw Exception('No internet connection');
      }

      debugPrint('[Update] Starting download from: $_downloadUrl');

      // Use HttpClientService for download with progress
      final bytes = await HttpClientService.downloadFile(
        _downloadUrl!,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Download failed - no data received');
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = _downloadUrl!.split('/').last;
      final filePath = '${tempDir.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      _downloadedFilePath = filePath;
      _downloadComplete = true;
      _isDownloading = false;
      _downloadProgress = 1.0;
      notifyListeners();

      debugPrint('[Update] Downloaded to: $filePath');
      return true;
    } on TimeoutException {
      debugPrint('[Update] Download timed out');
      _error = 'Download timed out. Please try again.';
      _isDownloading = false;
      notifyListeners();
      return false;
    } on SocketException catch (e) {
      debugPrint('[Update] Network error during download: $e');
      _error = 'Network error during download.';
      _isDownloading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[Update] Download error: $e');
      _error = e.toString();
      _isDownloading = false;
      notifyListeners();
      return false;
    }
  }

  /// Install the downloaded update
  Future<bool> installUpdate() async {
    if (_downloadedFilePath == null) return false;

    try {
      final file = File(_downloadedFilePath!);
      if (!await file.exists()) {
        _error = 'Downloaded file not found';
        notifyListeners();
        return false;
      }

      // Run the installer
      if (Platform.isWindows) {
        debugPrint('[Update] Launching installer: $_downloadedFilePath');

        await Process.start(
          _downloadedFilePath!,
          [],
          mode: ProcessStartMode.detached,
        );

        // Save flag to skip update check on next launch
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('just_updated', true);
        await prefs.setString('updated_to_version', _latestVersion ?? '');

        // Exit app to allow installation
        exit(0);
      }

      return true;
    } catch (e) {
      debugPrint('[Update] Install error: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Skip this version
  Future<void> skipVersion() async {
    if (_latestVersion != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('skipped_version', _latestVersion!);
      _updateAvailable = false;
      notifyListeners();
    }
  }

  /// Check if version was skipped
  Future<bool> isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString('skipped_version');
    return skipped == version;
  }

  /// Get last check time
  Future<DateTime?> getLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastCheckKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (_) {}
    return null;
  }

  /// Reset update state
  void reset() {
    _isChecking = false;
    _isDownloading = false;
    _updateAvailable = false;
    _downloadComplete = false;
    _downloadProgress = 0.0;
    _latestVersion = null;
    _downloadUrl = null;
    _releaseNotes = null;
    _downloadedFilePath = null;
    _error = null;
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    stopBackgroundChecking();
    super.dispose();
  }

  /// Get formatted file size
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
