import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import '../services/whatsapp_business_api_service.dart';
import '../services/http_client_service.dart';
import '../config/secrets.dart';

/// User account status enum
enum UserAccountStatus {
  notRegistered, // لم يتم التسجيل من قبل
  pendingApproval, // مسجل وفي انتظار الموافقة
  activated, // تم التفعيل والموافقة
  suspended, // موقوف
}

/// User account information
class UserAccountInfo {
  final String email;
  final String? name;
  final String? phone;
  final UserAccountStatus status;
  final String? hwid;
  final DateTime? registrationDate;
  final DateTime? activationDate;
  final String? activationKey;
  final bool hasActivationFile;

  UserAccountInfo({
    required this.email,
    this.name,
    this.phone,
    required this.status,
    this.hwid,
    this.registrationDate,
    this.activationDate,
    this.activationKey,
    this.hasActivationFile = false,
  });

  bool get isApproved => status == UserAccountStatus.activated;
  bool get isPending => status == UserAccountStatus.pendingApproval;
  bool get canRenewActivation => isApproved && hasActivationFile;
}

/// Activation and License Management Provider
/// Compatible with Python version on GitHub
class ActivationProvider extends ChangeNotifier {
  // WhatsApp Business API Service
  final WhatsAppBusinessApiService _whatsAppService =
      WhatsAppBusinessApiService();

  // Device binding state
  bool _isDeviceBound = false;
  String? _boundDeviceId;
  // ignore: unused_field
  DateTime? _lastDeviceSwitch;

  // OTP verification state
  bool _isOtpVerified = false;
  // ignore: unused_field
  String? _pendingOtp;

  // User account status
  UserAccountStatus _accountStatus = UserAccountStatus.notRegistered;
  UserAccountInfo? _userAccountInfo;

  // Getters for device binding
  bool get isDeviceBound => _isDeviceBound;
  String? get boundDeviceId => _boundDeviceId;
  bool get isOtpVerified => _isOtpVerified;
  WhatsAppBusinessApiService get whatsAppService => _whatsAppService;

  // Getters for account status
  UserAccountStatus get accountStatus => _accountStatus;
  UserAccountInfo? get userAccountInfo => _userAccountInfo;
  // GitHub Configuration - Same as Python with multiple tokens support
  // Tokens are loaded from secrets file or environment variables
  static List<String> get _githubTokens {
    // First try environment variables, then fall back to secrets file
    final envToken1 = const String.fromEnvironment('GITHUB_TOKEN_1', defaultValue: '');
    final envToken2 = const String.fromEnvironment('GITHUB_TOKEN_2', defaultValue: '');
    
    if (envToken1.isNotEmpty || envToken2.isNotEmpty) {
      return [
        if (envToken1.isNotEmpty) envToken1,
        if (envToken2.isNotEmpty) envToken2,
      ];
    }
    
    // Fall back to secrets file
    return Secrets.githubTokens;
  }
  static int _currentTokenIndex = 0;
  static int _rateLimitRemaining = 5000;
  static int _rateLimitReset = 0;

  static const String _repoOwner = 'tiraUnderCode23';
  static const String _repoName = 'AQ';
  static const String _githubBranch = 'main';
  static const String _usersFile = 'users.json';

  /// Get valid token with rotation - matching Python's GitHubManager
  static String get _githubToken {
    final tokens = _githubTokens;
    if (tokens.isEmpty) return '';
    return tokens[_currentTokenIndex % tokens.length];
  }

  /// Rotate to next token
  static void _rotateToken() {
    _currentTokenIndex = (_currentTokenIndex + 1) % _githubTokens.length;
    debugPrint('[GitHub] Rotated to token index: $_currentTokenIndex');
  }

  /// Check and handle rate limiting
  static Future<void> _checkRateLimit() async {
    if (_rateLimitRemaining <= 10) {
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final resetTime = _rateLimitReset - currentTime;
      if (resetTime > 0) {
        debugPrint('[GitHub] Rate limited, waiting $resetTime seconds');
        await Future.delayed(Duration(seconds: resetTime + 1));
      }
    }
  }

  /// Update rate limit info from response headers
  static void _updateRateLimitInfo(http.Response response) {
    final remaining = response.headers['x-ratelimit-remaining'];
    final reset = response.headers['x-ratelimit-reset'];
    if (remaining != null) {
      _rateLimitRemaining = int.tryParse(remaining) ?? 5000;
    }
    if (reset != null) {
      _rateLimitReset = int.tryParse(reset) ?? 0;
    }
  }

  // State
  bool _isActivated = false;
  bool _isLoading = false;
  String? _activationCode;
  String? _hwid;
  String? _email;
  String? _username;
  String? _phoneNumber;
  DateTime? _activationDate;
  DateTime? _expirationDate;
  String? _errorMessage;

  // Getters
  bool get isActivated => _isActivated;
  bool get isLoading => _isLoading;
  String? get activationCode => _activationCode;
  String? get activationKey => _activationCode;
  String? get hwid => _hwid;
  String? get machineId => _hwid;
  String? get deviceId => _hwid;
  String? get email => _email;
  String? get username => _username;
  String? get phoneNumber => _phoneNumber;
  DateTime? get activationDate => _activationDate;
  DateTime? get expirationDate => _expirationDate;
  String? get errorMessage => _errorMessage;
  String? get lastError => _errorMessage;
  bool get isExpired =>
      _expirationDate != null && DateTime.now().isAfter(_expirationDate!);

  ActivationProvider() {
    _initializeActivation();
  }

  /// Initialize
  Future<void> _initializeActivation() async {
    await _generateHWID();
    await _loadSavedActivation();

    // If already activated, verify with GitHub
    if (_isActivated && _email != null) {
      await verifyActivationWithGitHub();
    } else {
      // Check if there's a pending registration that got activated
      await checkPendingActivation();
    }
  }

  /// Generate HWID - Same format as Python version
  Future<void> _generateHWID() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = '';

      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        // Use same format as Python: computerName + deviceId
        deviceId = '${windowsInfo.computerName}_${windowsInfo.deviceId}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId =
            '${androidInfo.brand}_${androidInfo.model}_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId =
            '${iosInfo.name}_${iosInfo.identifierForVendor ?? "unknown"}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceId = '${macInfo.computerName}_${macInfo.systemGUID ?? "unknown"}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceId = '${linuxInfo.name}_${linuxInfo.machineId ?? "unknown"}';
      }

      // Hash the device ID - same as Python
      final bytes = utf8.encode(deviceId);
      final digest = sha256.convert(bytes);
      _hwid = digest.toString().substring(0, 32).toUpperCase();

      debugPrint('Generated HWID: $_hwid');
      notifyListeners();
    } catch (e) {
      debugPrint('Error generating HWID: $e');
      _hwid = _generateRandomHWID();
      notifyListeners();
    }
  }

  String _generateRandomHWID() {
    const chars = 'ABCDEF0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Convert email to filename format - Same as Python
  String _emailToFilename(String email) {
    return email.replaceAll('@', '_at_').replaceAll('.', '_dot_');
  }

  /// Get activation file path
  String _getActivationFilePath(String email) {
    return 'activations/${_emailToFilename(email)}_activation.dat';
  }

  /// GitHub API URL
  String _getGitHubApiUrl(String filePath) {
    return 'https://api.github.com/repos/$_repoOwner/$_repoName/contents/$filePath';
  }

  /// GitHub Raw URL
  String _getGitHubRawUrl(String filePath) {
    return 'https://raw.githubusercontent.com/$_repoOwner/$_repoName/$_githubBranch/$filePath';
  }

  /// Check activation status from GitHub
  Future<bool> checkActivationStatus() async {
    if (_email == null || _hwid == null) {
      return false;
    }
    return await verifyActivationWithGitHub();
  }

  /// Verify activation with GitHub - Same logic as Python
  Future<bool> verifyActivationWithGitHub() async {
    if (_email == null || _hwid == null) {
      _isActivated = false;
      notifyListeners();
      return false;
    }

    try {
      // 1. Check if activation file exists on GitHub
      final activationCode = await _getActivationFileFromGitHub(_email!);
      if (activationCode == null) {
        debugPrint('Activation file not found for email: $_email');
        _isActivated = false;
        _errorMessage = 'Activation file not found';
        await _clearActivation();
        notifyListeners();
        return false;
      }

      // 2. Check user data from both users.json and applications.json
      final usersData = await _getAllUsersFromGitHub();
      if (usersData == null) {
        debugPrint('Failed to get users data');
        _errorMessage = 'Failed to retrieve user data';
        _isActivated = false;
        notifyListeners();
        return false;
      }

      // 3. Find user and verify HWID
      for (var user in usersData) {
        if (user['email'] == _email) {
          final userHwid = user['hwid'] ?? '';

          // Check if HWID matches
          if (userHwid.isNotEmpty && userHwid != _hwid) {
            debugPrint('HWID mismatch: expected $userHwid, got $_hwid');
            _errorMessage = 'This account is registered on another device';
            _isActivated = false;
            await _clearActivation();
            notifyListeners();
            return false;
          }

          // User found and HWID matches (or no HWID set yet)
          _isActivated = true;
          _activationCode = activationCode;
          _username = user['name'] ?? user['username'];
          _phoneNumber = user['phone'];
          await _saveActivation();
          notifyListeners();
          return true;
        }
      }

      // User not found
      _errorMessage = 'User not found';
      _isActivated = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error verifying activation: $e');
      _errorMessage = 'Verification error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get activation file content from GitHub with rate limit handling
  Future<String?> _getActivationFileFromGitHub(String email) async {
    try {
      await _checkRateLimit();
      final filePath = _getActivationFilePath(email);
      final apiUrl = _getGitHubApiUrl(filePath);

      final response = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 15));

      _updateRateLimitInfo(response);
      debugPrint('Get activation file response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['content'] as String?;
        if (content != null) {
          return utf8.decode(base64.decode(content.replaceAll('\n', '')));
        }
      } else if (response.statusCode == 404) {
        debugPrint('Activation file not found');
        return null;
      } else if (response.statusCode == 403) {
        // Rate limited - rotate token and retry
        _rotateToken();
        return await _getActivationFileFromGitHub(email);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting activation file: $e');
      return null;
    }
  }

  /// Get users.json from GitHub with rate limit handling
  Future<List<dynamic>?> _getUsersFromGitHub() async {
    try {
      await _checkRateLimit();
      // Try raw URL first (faster)
      final rawUrl = _getGitHubRawUrl(_usersFile);
      var response = await HttpClientService.client.get(
        Uri.parse(rawUrl),
        headers: {
          'Authorization': 'token $_githubToken',
        },
      ).timeout(const Duration(seconds: 15));

      _updateRateLimitInfo(response);

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else if (response.statusCode == 403) {
        // Rate limited - rotate token and retry
        _rotateToken();
        return await _getUsersFromGitHub();
      }

      // Fallback to API
      final apiUrl = _getGitHubApiUrl(_usersFile);
      response = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content =
            utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));
        return json.decode(content) as List<dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting users: $e');
      return null;
    }
  }

  /// Get applications.json from GitHub (for pending registrations)
  Future<List<dynamic>?> _getApplicationsFromGitHub() async {
    try {
      final apiUrl = _getGitHubApiUrl('applications.json');
      final response = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content =
            utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));
        return json.decode(content) as List<dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting applications: $e');
      return null;
    }
  }

  /// Get combined users from both users.json and applications.json
  Future<List<dynamic>?> _getAllUsersFromGitHub() async {
    final List<dynamic> allUsers = [];

    // Get users from users.json
    final usersData = await _getUsersFromGitHub();
    if (usersData != null) {
      allUsers.addAll(usersData);
    }

    // Get approved applications from applications.json
    final applicationsData = await _getApplicationsFromGitHub();
    if (applicationsData != null) {
      for (var app in applicationsData) {
        // Check if already in users list
        bool exists = allUsers.any((u) => u['email'] == app['email']);
        if (!exists) {
          allUsers.add(app);
        }
      }
    }

    return allUsers.isEmpty ? null : allUsers;
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Get users from GitHub
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Find user by email
      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (user['email'] == email) {
          foundUser = user as Map<String, dynamic>;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'Email not registered';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 3. Verify password (hash and compare)
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      final storedHash =
          foundUser['password'] ?? foundUser['password_hash'] ?? '';

      if (passwordHash != storedHash && password != storedHash) {
        _errorMessage = 'Incorrect password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 4. Check if activation file exists
      final activationCode = await _getActivationFileFromGitHub(email);
      if (activationCode == null) {
        _errorMessage = 'Account not activated. Please contact support';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 5. Check HWID - Device binding with 24h cooldown
      final userHwid = foundUser['hwid'] ?? '';
      if (userHwid.isNotEmpty && userHwid != _hwid) {
        // Account is linked to another device
        _boundDeviceId = userHwid;
        _isDeviceBound = true;
        _errorMessage = 'DEVICE_MISMATCH'; // Special error code for UI handling
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 6. Update HWID if not set
      if (userHwid.isEmpty) {
        await _updateUserHWID(email, _hwid!);
        _boundDeviceId = _hwid;
        _isDeviceBound = true;
      }

      // 7. Success - Save activation
      _isActivated = true;
      _email = email;
      _activationCode = activationCode;
      _username = foundUser['name'] ?? foundUser['username'] ?? email;
      _phoneNumber = foundUser['phone'];
      _activationDate = DateTime.now();

      await _saveActivation();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      _errorMessage = 'Login error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Activate with key (activation code)
  /// Compares entered key with existing activation files, handles re-activation
  Future<bool> activateWithKey(String key) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get all users from both users.json and applications.json
      final usersData = await _getAllUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Find user with matching activation code
      for (var user in usersData) {
        final userEmail = user['email'] as String?;
        if (userEmail == null) continue;

        // Check activation file
        final activationCode = await _getActivationFileFromGitHub(userEmail);
        if (activationCode != null && activationCode.trim() == key.trim()) {
          // Check HWID
          final userHwid = user['hwid'] ?? '';

          // If HWID exists and doesn't match current device
          if (userHwid.isNotEmpty && userHwid != _hwid) {
            // Check if this is the same user trying to switch devices
            // Allow if the local email matches (re-activation on new device)
            if (_email != null && _email == userEmail) {
              // User is trying to re-activate their own account on a new device
              // This should go through device switch flow instead
              _errorMessage =
                  'This key is bound to another device. Use device switch to transfer activation.';
            } else {
              _errorMessage = 'Activation code is used on another device';
            }
            _isLoading = false;
            notifyListeners();
            return false;
          }

          // Update HWID if not set or if it matches (re-activation)
          if (userHwid.isEmpty || userHwid == _hwid) {
            if (userHwid.isEmpty) {
              await _updateUserHWID(userEmail, _hwid!);
            }

            // Success - Activate or Re-activate
            _isActivated = true;
            _email = userEmail;
            _activationCode = activationCode;
            _username = user['name'] ?? user['username'] ?? userEmail;
            _phoneNumber = user['phone'];
            _activationDate = DateTime.now();

            await _saveActivation();

            debugPrint('Successfully activated account for $userEmail');

            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
      }

      // If we get here, key wasn't found - check if user might have a typo
      // or if the key exists but HWID doesn't match
      _errorMessage = 'Invalid activation code. Please check and try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Activation error: $e');
      _errorMessage = 'Activation error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update user HWID on GitHub
  Future<bool> _updateUserHWID(String email, String hwid) async {
    try {
      // Get current users file
      final apiUrl = _getGitHubApiUrl(_usersFile);
      final getResponse = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode != 200) return false;

      final data = json.decode(getResponse.body);
      final sha = data['sha'];
      final content =
          utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));
      final users = json.decode(content) as List<dynamic>;

      // Find and update user
      bool updated = false;
      for (var i = 0; i < users.length; i++) {
        if (users[i]['email'] == email) {
          users[i]['hwid'] = hwid;
          users[i]['last_login'] = DateTime.now().toIso8601String();
          updated = true;
          break;
        }
      }

      if (!updated) return false;

      // Update file on GitHub
      final newContent = base64.encode(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(users)));

      final putResponse = await HttpClientService.client.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': 'Update HWID for $email',
          'content': newContent,
          'sha': sha,
          'branch': _githubBranch,
        }),
      );

      return putResponse.statusCode == 200 || putResponse.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating HWID: $e');
      return false;
    }
  }

  /// Register new user - Creates application request
  Future<bool> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if email already exists
      final usersData = await _getUsersFromGitHub();
      if (usersData != null) {
        for (var user in usersData) {
          if (user['email'] == email) {
            _errorMessage = 'Email is already registered';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }
      }

      // Get applications.json to add request
      final applicationsUrl = _getGitHubApiUrl('applications.json');
      final getResponse = await HttpClientService.client.get(
        Uri.parse(applicationsUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      List<dynamic> applications = [];
      String? sha;

      if (getResponse.statusCode == 200) {
        final data = json.decode(getResponse.body);
        sha = data['sha'];
        final content =
            utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));
        applications = json.decode(content) as List<dynamic>;
      }

      // Hash password
      final passwordHash = sha256.convert(utf8.encode(password)).toString();

      // Create new application
      final newApplication = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'email': email,
        'phone': phone,
        'password': passwordHash,
        'hwid': _hwid,
        'registration_time': DateTime.now().toIso8601String(),
        'status': 'pending',
        'platform': Platform.operatingSystem,
      };

      applications.add(newApplication);

      // Update file on GitHub
      final newContent = base64.encode(utf8
          .encode(const JsonEncoder.withIndent('  ').convert(applications)));

      final putResponse = await HttpClientService.client.put(
        Uri.parse(applicationsUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': 'New registration request: $email',
          'content': newContent,
          if (sha != null) 'sha': sha,
          'branch': _githubBranch,
        }),
      );

      if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to send registration request';
        debugPrint('Registration failed: ${putResponse.body}');
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      _errorMessage = 'Registration error: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Load saved activation from local storage
  Future<void> _loadSavedActivation() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isActivated = prefs.getBool('isActivated') ?? false;
      _email = prefs.getString('email');
      _activationCode = prefs.getString('activationCode');
      _username = prefs.getString('username');
      _phoneNumber = prefs.getString('phoneNumber');

      final activationDateStr = prefs.getString('activationDate');
      if (activationDateStr != null) {
        _activationDate = DateTime.tryParse(activationDateStr);
      }

      final expirationDateStr = prefs.getString('expirationDate');
      if (expirationDateStr != null) {
        _expirationDate = DateTime.tryParse(expirationDateStr);
      }

      // Check expiration
      if (_isActivated && isExpired) {
        _isActivated = false;
        await _clearActivation();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading activation: $e');
    }
  }

  /// Save activation to local storage
  Future<void> _saveActivation() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isActivated', _isActivated);
      if (_email != null) {
        await prefs.setString('email', _email!);
      }
      if (_activationCode != null) {
        await prefs.setString('activationCode', _activationCode!);
      }
      if (_username != null) {
        await prefs.setString('username', _username!);
      }
      if (_phoneNumber != null) {
        await prefs.setString('phoneNumber', _phoneNumber!);
      }
      if (_activationDate != null) {
        await prefs.setString(
            'activationDate', _activationDate!.toIso8601String());
      }
      if (_expirationDate != null) {
        await prefs.setString(
            'expirationDate', _expirationDate!.toIso8601String());
      }
    } catch (e) {
      debugPrint('Error saving activation: $e');
    }
  }

  /// Clear activation data
  Future<void> _clearActivation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isActivated');
      await prefs.remove('email');
      await prefs.remove('activationCode');
      await prefs.remove('username');
      await prefs.remove('phoneNumber');
      await prefs.remove('activationDate');
      await prefs.remove('expirationDate');
    } catch (e) {
      debugPrint('Error clearing activation: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    _isActivated = false;
    _email = null;
    _activationCode = null;
    _username = null;
    _phoneNumber = null;
    _activationDate = null;
    _expirationDate = null;
    await _clearActivation();
    notifyListeners();
  }

  /// Delete registration from GitHub - matching Python's delete_and_create_new
  Future<bool> deleteRegistration() async {
    if (_email == null) {
      // Try to get pending email
      final pendingEmail = await getPendingRegistrationEmail();
      if (pendingEmail == null) {
        await logout();
        return true;
      }
      _email = pendingEmail;
    }

    try {
      // 1. Delete activation file from GitHub
      await _deleteActivationFileFromGitHub(_email!);

      // 2. Remove user from users.json
      await _removeUserFromGitHub(_email!);

      // 3. Remove user from applications.json
      await _removeUserFromApplications(_email!);

      // 4. Clear local data
      await logout();

      // 5. Clear pending registration and device binding
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pendingEmail');
      await prefs.remove('registrationStatus');
      await prefs.remove('last_device_switch_$_email');

      debugPrint('Successfully deleted registration for $_email');
      return true;
    } catch (e) {
      debugPrint('Error deleting registration: $e');
      // Still clear local data even if GitHub fails
      await logout();
      return false;
    }
  }

  /// Remove user from applications.json on GitHub
  Future<bool> _removeUserFromApplications(String email) async {
    try {
      final apiUrl = _getGitHubApiUrl('applications.json');

      // Get current applications file
      final getResponse = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode != 200) return false;

      final data = json.decode(getResponse.body);
      final sha = data['sha'];
      final content =
          utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));
      final applications = json.decode(content) as List<dynamic>;

      // Find and remove application
      final initialLength = applications.length;
      applications.removeWhere((app) => app['email'] == email);

      if (applications.length == initialLength) {
        debugPrint('User not found in applications.json');
        return true; // Not found is okay
      }

      // Update file on GitHub
      final newContent = base64.encode(utf8
          .encode(const JsonEncoder.withIndent('  ').convert(applications)));

      final putResponse = await HttpClientService.client.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': 'Remove application $email',
          'content': newContent,
          'sha': sha,
          'branch': _githubBranch,
        }),
      );

      return putResponse.statusCode == 200 || putResponse.statusCode == 201;
    } catch (e) {
      debugPrint('Error removing user from applications: $e');
      return false;
    }
  }

  /// Switch device - removes old HWID and sets new one with 24h cooldown
  Future<Map<String, dynamic>> switchDevice(
      String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check 24h cooldown
      final canSwitch = await _whatsAppService.canSwitchDevice(email);
      if (!canSwitch) {
        final remaining =
            await _whatsAppService.getDeviceSwitchCooldownRemaining(email);
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;
        _errorMessage =
            'يجب الانتظار $hours ساعة و $minutes دقيقة قبل تبديل الجهاز';
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'error': 'COOLDOWN',
          'remaining': remaining,
        };
      }

      // 2. Verify user credentials
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (user['email'] == email) {
          foundUser = user as Map<String, dynamic>;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'Email not registered';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      // 3. Verify password
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      final storedHash =
          foundUser['password'] ?? foundUser['password_hash'] ?? '';

      if (passwordHash != storedHash && password != storedHash) {
        _errorMessage = 'Incorrect password';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'WRONG_PASSWORD'};
      }

      // 4. Update HWID to new device
      final success = await _updateUserHWID(email, _hwid!);
      if (!success) {
        _errorMessage = 'Failed to update device';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'UPDATE_FAILED'};
      }

      // 5. Record device switch time
      await _whatsAppService.recordDeviceSwitch(email);

      // 6. Send notification via WhatsApp
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;
      final phone = foundUser['phone'] ?? '';
      if (phone.isNotEmpty) {
        await _whatsAppService.sendDeviceSwitchNotification(
          phoneNumber: phone,
          userName: userName,
          newDeviceId: _hwid!,
        );
      }

      // 7. Update local state
      _boundDeviceId = _hwid;
      _isDeviceBound = true;
      _lastDeviceSwitch = DateTime.now();

      _isLoading = false;
      notifyListeners();
      return {'success': true};
    } catch (e) {
      debugPrint('Device switch error: $e');
      _errorMessage = 'Device switch error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// Send password recovery via WhatsApp (only for activated accounts)
  Future<bool> sendPasswordRecoveryViaWhatsApp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get user data
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (user['email'] == email) {
          foundUser = user as Map<String, dynamic>;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'Email not registered';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if account is activated
      final activationCode = await _getActivationFileFromGitHub(email);
      if (activationCode == null) {
        _errorMessage =
            'Account not activated. Password recovery via WhatsApp is only available for activated accounts.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get phone number
      final phone = foundUser['phone'] ?? '';
      if (phone.isEmpty) {
        _errorMessage = 'No phone number registered for this account';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get password hash (we can't recover plain password, so generate new one)
      final newPassword = _generateTemporaryPassword();
      final newPasswordHash =
          sha256.convert(utf8.encode(newPassword)).toString();

      // Update password in GitHub
      await _updateUserPassword(email, newPasswordHash);

      // Send via WhatsApp
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;
      final success = await _whatsAppService.sendPasswordRecovery(
        phoneNumber: phone,
        userName: userName,
        password: newPassword,
        isActivated: true,
      );

      if (success) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to send password via WhatsApp';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Password recovery error: $e');
      _errorMessage = 'Password recovery error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Generate temporary password
  String _generateTemporaryPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Update user password on GitHub
  Future<bool> _updateUserPassword(String email, String passwordHash) async {
    try {
      final apiUrl = _getGitHubApiUrl(_usersFile);
      final getResponse = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode != 200) return false;

      final data = json.decode(getResponse.body);
      final sha = data['sha'];
      final content =
          utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));
      final users = json.decode(content) as List<dynamic>;

      // Find and update user
      bool updated = false;
      for (var i = 0; i < users.length; i++) {
        if (users[i]['email'] == email) {
          users[i]['password'] = passwordHash;
          users[i]['password_updated'] = DateTime.now().toIso8601String();
          updated = true;
          break;
        }
      }

      if (!updated) return false;

      // Update file on GitHub
      final newContent = base64.encode(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(users)));

      final putResponse = await HttpClientService.client.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': 'Update password for $email',
          'content': newContent,
          'sha': sha,
          'branch': _githubBranch,
        }),
      );

      return putResponse.statusCode == 200 || putResponse.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating password: $e');
      return false;
    }
  }

  /// Send OTP for phone verification during registration
  Future<bool> sendOtpForRegistration(String phone, String name) async {
    final otp = await _whatsAppService.sendOtpForRegistration(
      phoneNumber: phone,
      userName: name,
    );
    if (otp != null) {
      _pendingOtp = otp;
      return true;
    }
    return false;
  }

  /// Verify OTP code
  bool verifyOtp(String phone, String otp) {
    final verified = _whatsAppService.verifyOtp(
      phoneNumber: phone,
      otp: otp,
    );
    if (verified) {
      _isOtpVerified = true;
      notifyListeners();
    }
    return verified;
  }

  /// Reset OTP verification state
  void resetOtpVerification() {
    _isOtpVerified = false;
    _pendingOtp = null;
    notifyListeners();
  }

  /// Delete activation file from GitHub - matching Python
  Future<bool> _deleteActivationFileFromGitHub(String email) async {
    try {
      final filePath = _getActivationFilePath(email);
      final apiUrl = _getGitHubApiUrl(filePath);

      // First get the file to get its SHA
      final getResponse = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode == 404) {
        debugPrint('Activation file not found - may already be deleted');
        return true;
      }

      if (getResponse.statusCode != 200) {
        debugPrint(
            'Could not access activation file: ${getResponse.statusCode}');
        return false;
      }

      final data = json.decode(getResponse.body);
      final sha = data['sha'];

      // Delete the file
      final deleteResponse = await HttpClientService.client.delete(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': 'Delete activation file for $email',
          'sha': sha,
          'branch': _githubBranch,
        }),
      );

      return deleteResponse.statusCode == 200 ||
          deleteResponse.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting activation file: $e');
      return false;
    }
  }

  /// Remove user from users.json on GitHub
  Future<bool> _removeUserFromGitHub(String email) async {
    try {
      final apiUrl = _getGitHubApiUrl(_usersFile);

      // Get current users file
      final getResponse = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode != 200) return false;

      final data = json.decode(getResponse.body);
      final sha = data['sha'];
      final content =
          utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));
      final users = json.decode(content) as List<dynamic>;

      // Find and remove user
      final initialLength = users.length;
      users.removeWhere((user) => user['email'] == email);

      if (users.length == initialLength) {
        debugPrint('User not found in users.json');
        return false;
      }

      // Update file on GitHub
      final newContent = base64.encode(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(users)));

      final putResponse = await HttpClientService.client.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': 'Remove user $email',
          'content': newContent,
          'sha': sha,
          'branch': _githubBranch,
        }),
      );

      return putResponse.statusCode == 200 || putResponse.statusCode == 201;
    } catch (e) {
      debugPrint('Error removing user from GitHub: $e');
      return false;
    }
  }

  /// Save pending registration email for later activation check
  Future<void> savePendingRegistration(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pendingEmail', email);
      await prefs.setString('registrationStatus', 'pending');
      _email = email;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving pending registration: $e');
    }
  }

  /// Get pending registration email
  Future<String?> getPendingRegistrationEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('pendingEmail');
    } catch (e) {
      debugPrint('Error getting pending email: $e');
      return null;
    }
  }

  /// Check if there's a pending registration that got activated
  Future<bool> checkPendingActivation() async {
    try {
      final pendingEmail = await getPendingRegistrationEmail();
      if (pendingEmail == null) return false;

      // Check if activation file now exists on GitHub
      final activationCode = await _getActivationFileFromGitHub(pendingEmail);
      if (activationCode != null) {
        // Activation file exists! User has been activated
        _email = pendingEmail;
        _activationCode = activationCode;
        _isActivated = true;
        _activationDate = DateTime.now();

        // Get user info from both users.json and applications.json
        final usersData = await _getAllUsersFromGitHub();
        if (usersData != null) {
          for (var user in usersData) {
            if (user['email'] == pendingEmail) {
              _username = user['name'] ?? user['username'];
              _phoneNumber = user['phone'];

              // Update HWID if needed
              final userHwid = user['hwid'] ?? '';
              if (userHwid.isEmpty && _hwid != null) {
                await _updateUserHWID(pendingEmail, _hwid!);
              }
              break;
            }
          }
        }

        // Clear pending status and save activation
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pendingEmail');
        await prefs.setString('registrationStatus', 'activated');
        await _saveActivation();

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking pending activation: $e');
      return false;
    }
  }

  /// Get registration status
  Future<String> getRegistrationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('registrationStatus') ?? 'none';
    } catch (e) {
      return 'none';
    }
  }

  /// Generate activation code in format XXXXX-XXXXXXXX-XXXXX
  static String generateActivationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    String part1 =
        List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
    String part2 =
        List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
    String part3 =
        List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();

    return '$part1-$part2-$part3';
  }

  // ============================================================================
  // نظام إدارة الحسابات المحسن
  // Enhanced Account Management System
  // ============================================================================

  /// التحقق من حالة الحساب بشكل شامل
  /// Check user account status comprehensively
  Future<UserAccountInfo?> checkUserAccountStatus(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. البحث في users.json (المستخدمين المفعلين)
      final usersData = await _getUsersFromGitHub();
      Map<String, dynamic>? userInUsers;

      if (usersData != null) {
        for (var user in usersData) {
          if (user['email'] == email) {
            userInUsers = user as Map<String, dynamic>;
            break;
          }
        }
      }

      // 2. البحث في applications.json (طلبات التسجيل)
      final applicationsData = await _getApplicationsFromGitHub();
      Map<String, dynamic>? userInApplications;

      if (applicationsData != null) {
        for (var app in applicationsData) {
          if (app['email'] == email) {
            userInApplications = app as Map<String, dynamic>;
            break;
          }
        }
      }

      // 3. التحقق من وجود ملف التفعيل
      final activationCode = await _getActivationFileFromGitHub(email);
      final hasActivationFile = activationCode != null;

      // 4. تحديد حالة الحساب
      UserAccountStatus status;
      Map<String, dynamic>? userData;

      if (userInUsers != null && hasActivationFile) {
        // مستخدم مفعل بالكامل
        status = UserAccountStatus.activated;
        userData = userInUsers;
      } else if (userInUsers != null && !hasActivationFile) {
        // مستخدم في users.json لكن بدون ملف تفعيل (يحتاج تجديد)
        status = UserAccountStatus.pendingApproval;
        userData = userInUsers;
      } else if (userInApplications != null) {
        // طلب تسجيل في الانتظار
        status = UserAccountStatus.pendingApproval;
        userData = userInApplications;
      } else {
        // غير مسجل
        status = UserAccountStatus.notRegistered;
      }

      _userAccountInfo = UserAccountInfo(
        email: email,
        name: userData?['name'] ?? userData?['username'],
        phone: userData?['phone'],
        status: status,
        hwid: userData?['hwid'],
        registrationDate: userData?['registration_time'] != null
            ? DateTime.tryParse(userData!['registration_time'])
            : null,
        activationDate: userData?['activation_time'] != null
            ? DateTime.tryParse(userData!['activation_time'])
            : null,
        activationKey: activationCode,
        hasActivationFile: hasActivationFile,
      );

      _accountStatus = status;
      _isLoading = false;
      notifyListeners();

      return _userAccountInfo;
    } catch (e) {
      debugPrint('Error checking account status: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// تجديد رمز التفعيل للمستخدم المفعل مسبقاً
  /// Renew activation key for previously activated user
  Future<Map<String, dynamic>> renewActivationKey(
      String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. التحقق من المستخدم وكلمة المرور
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'فشل الاتصال بالخادم';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (user['email'] == email) {
          foundUser = user as Map<String, dynamic>;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'البريد الإلكتروني غير مسجل';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      // 2. التحقق من كلمة المرور
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      final storedHash =
          foundUser['password'] ?? foundUser['password_hash'] ?? '';

      if (passwordHash != storedHash && password != storedHash) {
        _errorMessage = 'كلمة المرور غير صحيحة';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'WRONG_PASSWORD'};
      }

      // 3. حذف ملف التفعيل القديم
      await _deleteActivationFileFromGitHub(email);
      debugPrint('[Renewal] Deleted old activation file for $email');

      // 4. إنشاء رمز تفعيل جديد
      final newActivationCode = generateActivationCode();

      // 5. إنشاء ملف تفعيل جديد على GitHub
      final createSuccess =
          await _createActivationFileOnGitHub(email, newActivationCode);

      if (!createSuccess) {
        _errorMessage = 'فشل إنشاء رمز التفعيل الجديد';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CREATE_FAILED'};
      }

      // 6. تحديث HWID للجهاز الجديد
      await _updateUserHWID(email, _hwid!);

      // 7. إرسال رمز التفعيل الجديد عبر واتساب
      final phone = foundUser['phone'] ?? '';
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;

      if (phone.isNotEmpty) {
        await _whatsAppService.sendActivationKeyRenewal(
          phoneNumber: phone,
          userName: userName,
          activationKey: newActivationCode,
        );
        debugPrint('[Renewal] Sent new activation key via WhatsApp to $phone');
      }

      // 8. تحديث الحالة المحلية
      _activationCode = newActivationCode;
      _email = email;
      _username = userName;
      _phoneNumber = phone;
      _isActivated = true;
      _activationDate = DateTime.now();
      await _saveActivation();

      _isLoading = false;
      notifyListeners();

      return {
        'success': true,
        'activationKey': newActivationCode,
        'message': 'تم تجديد رمز التفعيل بنجاح وإرساله عبر واتساب'
      };
    } catch (e) {
      debugPrint('Renewal error: $e');
      _errorMessage = 'خطأ في تجديد التفعيل: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// إنشاء ملف تفعيل جديد على GitHub
  /// Creates or updates an activation file on GitHub
  Future<bool> _createActivationFileOnGitHub(
      String email, String activationCode) async {
    try {
      final filePath = _getActivationFilePath(email);
      final apiUrl = _getGitHubApiUrl(filePath);

      // First, check if file already exists to get its SHA
      String? existingSha;
      String? existingCode;
      final getResponse = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode == 200) {
        // File exists - get SHA and existing content
        final data = json.decode(getResponse.body);
        existingSha = data['sha'];
        existingCode =
            utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));

        // If the existing code is the same, no need to update
        if (existingCode.trim() == activationCode.trim()) {
          debugPrint(
              'Activation file already exists with same code for $email');
          return true;
        }
        debugPrint('Updating existing activation file for $email');
      }

      // Create or update the file
      final body = {
        'message': existingSha != null
            ? 'Update activation file for $email'
            : 'Create activation file for $email',
        'content': base64.encode(utf8.encode(activationCode)),
        'branch': _githubBranch,
      };

      // Include SHA if updating existing file
      if (existingSha != null) {
        body['sha'] = existingSha;
      }

      final response = await HttpClientService.client.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(
            'Successfully ${existingSha != null ? 'updated' : 'created'} activation file for $email');
        return true;
      } else {
        debugPrint(
            'Failed to create/update activation file: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error creating activation file: $e');
      return false;
    }
  }

  /// إرسال معلومات التسجيل للمستخدم الجديد (بدون الباسورد والمفتاح)
  /// Send registration info to new user (without password and key)
  Future<bool> sendRegistrationInfoToNewUser({
    required String name,
    required String email,
    required String phone,
  }) async {
    try {
      final success = await _whatsAppService.sendNewUserRegistrationInfo(
        phoneNumber: phone,
        userName: name,
        email: email,
      );

      if (success) {
        debugPrint('[Registration] Sent registration info to $phone');
      }

      return success;
    } catch (e) {
      debugPrint('Error sending registration info: $e');
      return false;
    }
  }

  /// تسجيل مستخدم جديد محسن مع إرسال رسالة واتساب
  /// Enhanced user registration with WhatsApp message
  Future<bool> registerUserEnhanced({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. التحقق من حالة الحساب أولاً
      final accountInfo = await checkUserAccountStatus(email);

      if (accountInfo != null) {
        if (accountInfo.status == UserAccountStatus.activated) {
          // الحساب مفعل - يجب استخدام تجديد التفعيل
          _errorMessage = 'هذا الحساب مفعل بالفعل. استخدم تجديد رمز التفعيل';
          _isLoading = false;
          notifyListeners();
          return false;
        } else if (accountInfo.status == UserAccountStatus.pendingApproval) {
          // الحساب في الانتظار
          _errorMessage = 'هذا الحساب في انتظار الموافقة';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // 2. تسجيل المستخدم العادي
      final registerSuccess = await registerUser(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );

      if (!registerSuccess) {
        return false;
      }

      // 3. إرسال معلومات التسجيل للمستخدم (بدون الباسورد والمفتاح)
      await sendRegistrationInfoToNewUser(
        name: name,
        email: email,
        phone: phone,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Enhanced registration error: $e');
      _errorMessage = 'خطأ في التسجيل: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// الحصول على كلمة المرور للمستخدم المفعل
  /// Get password for activated user (via WhatsApp)
  Future<Map<String, dynamic>> requestPasswordViaWhatsApp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. التحقق من حالة الحساب
      final accountInfo = await checkUserAccountStatus(email);

      if (accountInfo == null) {
        _errorMessage = 'لم يتم العثور على الحساب';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_FOUND'};
      }

      if (accountInfo.status != UserAccountStatus.activated) {
        _errorMessage = 'هذه الخدمة متاحة فقط للحسابات المفعلة';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_ACTIVATED'};
      }

      // 2. إرسال كلمة المرور عبر واتساب
      final success = await sendPasswordRecoveryViaWhatsApp(email);

      _isLoading = false;
      notifyListeners();

      return {
        'success': success,
        'message': success
            ? 'تم إرسال كلمة المرور إلى رقم واتساب المسجل'
            : _errorMessage
      };
    } catch (e) {
      _errorMessage = 'خطأ: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// طلب رمز التفعيل للمستخدم المفعل
  /// Request activation key for activated user (via WhatsApp)
  Future<Map<String, dynamic>> requestActivationKeyViaWhatsApp(
      String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. التحقق من حالة الحساب
      final accountInfo = await checkUserAccountStatus(email);

      if (accountInfo == null) {
        _errorMessage = 'لم يتم العثور على الحساب';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_FOUND'};
      }

      if (accountInfo.status != UserAccountStatus.activated) {
        _errorMessage = 'هذه الخدمة متاحة فقط للحسابات المفعلة';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_ACTIVATED'};
      }

      // 2. التحقق من كلمة المرور
      final usersData = await _getUsersFromGitHub();
      Map<String, dynamic>? foundUser;

      if (usersData != null) {
        for (var user in usersData) {
          if (user['email'] == email) {
            foundUser = user as Map<String, dynamic>;
            break;
          }
        }
      }

      if (foundUser == null) {
        _errorMessage = 'المستخدم غير موجود';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      final storedHash =
          foundUser['password'] ?? foundUser['password_hash'] ?? '';

      if (passwordHash != storedHash && password != storedHash) {
        _errorMessage = 'كلمة المرور غير صحيحة';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'WRONG_PASSWORD'};
      }

      // 3. الحصول على رمز التفعيل
      final activationKey = await _getActivationFileFromGitHub(email);

      if (activationKey == null) {
        _errorMessage = 'لم يتم العثور على رمز التفعيل';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NO_ACTIVATION_KEY'};
      }

      // 4. إرسال رمز التفعيل عبر واتساب
      final phone = foundUser['phone'] ?? '';
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;

      if (phone.isEmpty) {
        _errorMessage = 'لا يوجد رقم هاتف مسجل';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NO_PHONE'};
      }

      final success = await _whatsAppService.sendActivationKey(
        phoneNumber: phone,
        userName: userName,
        activationKey: activationKey,
      );

      _isLoading = false;
      notifyListeners();

      return {
        'success': success,
        'message': success
            ? 'تم إرسال رمز التفعيل إلى رقم واتساب المسجل'
            : 'فشل الإرسال'
      };
    } catch (e) {
      _errorMessage = 'خطأ: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// تحديث كلمة المرور للمستخدم المفعل
  /// Update password for activated user
  Future<Map<String, dynamic>> updatePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. التحقق من حالة الحساب
      final accountInfo = await checkUserAccountStatus(email);

      if (accountInfo == null ||
          accountInfo.status != UserAccountStatus.activated) {
        _errorMessage = 'هذه الخدمة متاحة فقط للحسابات المفعلة';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_ACTIVATED'};
      }

      // 2. التحقق من كلمة المرور القديمة
      final usersData = await _getUsersFromGitHub();
      Map<String, dynamic>? foundUser;

      if (usersData != null) {
        for (var user in usersData) {
          if (user['email'] == email) {
            foundUser = user as Map<String, dynamic>;
            break;
          }
        }
      }

      if (foundUser == null) {
        _errorMessage = 'المستخدم غير موجود';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      final oldPasswordHash =
          sha256.convert(utf8.encode(oldPassword)).toString();
      final storedHash =
          foundUser['password'] ?? foundUser['password_hash'] ?? '';

      if (oldPasswordHash != storedHash && oldPassword != storedHash) {
        _errorMessage = 'كلمة المرور القديمة غير صحيحة';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'WRONG_PASSWORD'};
      }

      // 3. تحديث كلمة المرور
      final newPasswordHash =
          sha256.convert(utf8.encode(newPassword)).toString();
      final success = await _updateUserPassword(email, newPasswordHash);

      if (!success) {
        _errorMessage = 'فشل تحديث كلمة المرور';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'UPDATE_FAILED'};
      }

      // 4. إرسال إشعار عبر واتساب
      final phone = foundUser['phone'] ?? '';
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;

      if (phone.isNotEmpty) {
        await _whatsAppService.sendPasswordChangeNotification(
          phoneNumber: phone,
          userName: userName,
        );
      }

      _isLoading = false;
      notifyListeners();

      return {'success': true, 'message': 'تم تحديث كلمة المرور بنجاح'};
    } catch (e) {
      _errorMessage = 'خطأ: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// إدارة الأجهزة - إزالة الجهاز القديم وربط جهاز جديد
  /// Device management - remove old device and bind new one
  Future<Map<String, dynamic>> manageDeviceBinding({
    required String email,
    required String password,
    required bool unbindOldDevice,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. التحقق من حالة الحساب
      final accountInfo = await checkUserAccountStatus(email);

      if (accountInfo == null ||
          accountInfo.status != UserAccountStatus.activated) {
        _errorMessage = 'هذه الخدمة متاحة فقط للحسابات المفعلة';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_ACTIVATED'};
      }

      // 2. تبديل الجهاز
      final result = await switchDevice(email, password);

      if (result['success'] != true) {
        return result;
      }

      _isLoading = false;
      notifyListeners();

      return {
        'success': true,
        'message': 'تم ربط الجهاز الجديد بنجاح',
        'deviceId': _hwid,
      };
    } catch (e) {
      _errorMessage = 'خطأ: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// حذف التفعيل القديم وإعادة التفعيل
  /// Delete old activation and re-activate
  Future<Map<String, dynamic>> deleteAndReactivate({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. التحقق من الحساب
      final accountInfo = await checkUserAccountStatus(email);

      if (accountInfo == null) {
        _errorMessage = 'لم يتم العثور على الحساب';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_FOUND'};
      }

      if (accountInfo.status != UserAccountStatus.activated) {
        _errorMessage = 'Account not activated';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_ACTIVATED'};
      }

      // 2. Renew activation (deletes old and creates new)
      final result = await renewActivationKey(email, password);

      return result;
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// Update user email
  Future<Map<String, dynamic>> updateEmail({
    required String currentEmail,
    required String newEmail,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Verify current user credentials
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      int userIndex = -1;
      for (var i = 0; i < usersData.length; i++) {
        if (usersData[i]['email'] == currentEmail) {
          foundUser = usersData[i] as Map<String, dynamic>;
          userIndex = i;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'User not found';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      // 2. Verify password
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      final storedHash =
          foundUser['password'] ?? foundUser['password_hash'] ?? '';

      if (passwordHash != storedHash && password != storedHash) {
        _errorMessage = 'Incorrect password';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'WRONG_PASSWORD'};
      }

      // 3. Check if new email already exists
      for (var user in usersData) {
        if (user['email'] == newEmail) {
          _errorMessage = 'Email already in use';
          _isLoading = false;
          notifyListeners();
          return {'success': false, 'error': 'EMAIL_EXISTS'};
        }
      }

      // 4. Get activation file for old email
      final activationCode = await _getActivationFileFromGitHub(currentEmail);

      // 5. Update user email in users.json
      final apiUrl = _getGitHubApiUrl(_usersFile);
      final getResponse = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode != 200) {
        _errorMessage = 'Failed to get user data';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'GET_FAILED'};
      }

      final data = json.decode(getResponse.body);
      final sha = data['sha'];
      final content =
          utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));
      final users = json.decode(content) as List<dynamic>;

      users[userIndex]['email'] = newEmail;
      users[userIndex]['email_updated'] = DateTime.now().toIso8601String();

      final newContent = base64.encode(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(users)));

      final putResponse = await HttpClientService.client.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': 'Update email from $currentEmail to $newEmail',
          'content': newContent,
          'sha': sha,
          'branch': _githubBranch,
        }),
      );

      if (putResponse.statusCode != 200 && putResponse.statusCode != 201) {
        _errorMessage = 'Failed to update email';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'UPDATE_FAILED'};
      }

      // 6. If activation exists, create new file with new email and delete old
      if (activationCode != null) {
        await _createActivationFileOnGitHub(newEmail, activationCode);
        await _deleteActivationFileFromGitHub(currentEmail);
      }

      // 7. Update local state
      _email = newEmail;
      await _saveActivation();

      _isLoading = false;
      notifyListeners();
      return {'success': true, 'message': 'Email updated successfully'};
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// Update user phone number
  Future<Map<String, dynamic>> updatePhone({
    required String email,
    required String newPhone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Verify user credentials
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      int userIndex = -1;
      for (var i = 0; i < usersData.length; i++) {
        if (usersData[i]['email'] == email) {
          foundUser = usersData[i] as Map<String, dynamic>;
          userIndex = i;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'User not found';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      // 2. Verify password
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      final storedHash =
          foundUser['password'] ?? foundUser['password_hash'] ?? '';

      if (passwordHash != storedHash && password != storedHash) {
        _errorMessage = 'Incorrect password';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'WRONG_PASSWORD'};
      }

      // 3. Update user phone in users.json
      final apiUrl = _getGitHubApiUrl(_usersFile);
      final getResponse = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode != 200) {
        _errorMessage = 'Failed to get user data';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'GET_FAILED'};
      }

      final data = json.decode(getResponse.body);
      final sha = data['sha'];
      final content =
          utf8.decode(base64.decode(data['content'].replaceAll('\n', '')));
      final users = json.decode(content) as List<dynamic>;

      users[userIndex]['phone'] = newPhone;
      users[userIndex]['phone_updated'] = DateTime.now().toIso8601String();

      final newContent = base64.encode(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(users)));

      final putResponse = await HttpClientService.client.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': 'Update phone for $email',
          'content': newContent,
          'sha': sha,
          'branch': _githubBranch,
        }),
      );

      if (putResponse.statusCode != 200 && putResponse.statusCode != 201) {
        _errorMessage = 'Failed to update phone number';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'UPDATE_FAILED'};
      }

      // 4. Update local state
      _phoneNumber = newPhone;
      await _saveActivation();

      // 5. Send notification via WhatsApp
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;
      await _whatsAppService.sendPhoneChangeNotification(
        phoneNumber: newPhone,
        userName: userName,
      );

      _isLoading = false;
      notifyListeners();
      return {'success': true, 'message': 'Phone number updated successfully'};
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// Recover account via email or phone
  Future<Map<String, dynamic>> recoverAccountViaEmailOrPhone(
      String identifier) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Determine if it's email or phone
      bool isEmail = identifier.contains('@');

      // Get all users
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (isEmail) {
          if (user['email'] == identifier) {
            foundUser = user as Map<String, dynamic>;
            break;
          }
        } else {
          // Check phone number (with or without country code)
          String userPhone = user['phone'] ?? '';
          if (userPhone == identifier ||
              userPhone.endsWith(identifier) ||
              identifier
                  .endsWith(userPhone.replaceAll(RegExp(r'^\+\d+'), ''))) {
            foundUser = user as Map<String, dynamic>;
            break;
          }
        }
      }

      if (foundUser == null) {
        _errorMessage = isEmail ? 'Email not found' : 'Phone number not found';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_FOUND'};
      }

      // Get activation key
      final email = foundUser['email'];
      final activationCode = await _getActivationFileFromGitHub(email);

      if (activationCode == null) {
        _errorMessage = 'Account not activated yet';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NOT_ACTIVATED'};
      }

      // Send recovery info via WhatsApp
      final phone = foundUser['phone'] ?? '';
      if (phone.isEmpty) {
        _errorMessage = 'No phone number registered';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NO_PHONE'};
      }

      final userName = foundUser['name'] ?? foundUser['username'] ?? email;

      // Generate new password
      final newPassword = _generateTemporaryPassword();
      final newPasswordHash =
          sha256.convert(utf8.encode(newPassword)).toString();
      await _updateUserPassword(email, newPasswordHash);

      // Send recovery info
      await _whatsAppService.sendAccountRecovery(
        phoneNumber: phone,
        userName: userName,
        email: email,
        activationKey: activationCode,
        newPassword: newPassword,
      );

      _isLoading = false;
      notifyListeners();
      return {
        'success': true,
        'message': 'Recovery information sent to your WhatsApp',
        'email': email,
      };
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  // ============================================================
  // OTP-Based User Management Functions
  // All operations require OTP verification via WhatsApp
  // ============================================================

  /// Send OTP for user management operations (by email)
  /// Used for: password recovery, email change, activation key recovery/renewal
  Future<Map<String, dynamic>> sendOtpForUserManagement(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Find user by email
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (user['email'] == email) {
          foundUser = user as Map<String, dynamic>;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'Email not registered';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      // 2. Get phone number
      final phone = foundUser['phone'] ?? '';
      if (phone.isEmpty) {
        _errorMessage = 'No phone number registered for this account';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NO_PHONE'};
      }

      // 3. Send OTP
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;
      final otp = await _whatsAppService.sendOtpForRegistration(
        phoneNumber: phone,
        userName: userName,
      );

      if (otp != null) {
        _pendingOtp = otp;
        _isLoading = false;
        notifyListeners();
        return {
          'success': true,
          'message': 'OTP sent to your WhatsApp',
          'phone': _maskPhoneNumber(phone),
        };
      } else {
        _errorMessage = 'Failed to send OTP';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'OTP_SEND_FAILED'};
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// Mask phone number for display (e.g., +972****757)
  String _maskPhoneNumber(String phone) {
    if (phone.length < 6) return phone;
    final start = phone.substring(0, 4);
    final end = phone.substring(phone.length - 3);
    return '$start****$end';
  }

  /// Recover password using OTP verification
  Future<Map<String, dynamic>> recoverPasswordWithOtp({
    required String email,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Find user
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (user['email'] == email) {
          foundUser = user as Map<String, dynamic>;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'User not found';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      final phone = foundUser['phone'] ?? '';

      // 2. Verify OTP
      final verified = _whatsAppService.verifyOtp(
        phoneNumber: phone,
        otp: otp,
      );

      if (!verified) {
        _errorMessage = 'Invalid or expired OTP';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'INVALID_OTP'};
      }

      // 3. Generate new password
      final newPassword = _generateTemporaryPassword();
      final newPasswordHash =
          sha256.convert(utf8.encode(newPassword)).toString();

      // 4. Update password
      final success = await _updateUserPassword(email, newPasswordHash);
      if (!success) {
        _errorMessage = 'Failed to update password';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'UPDATE_FAILED'};
      }

      // 5. Send new password via WhatsApp
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;
      await _whatsAppService.sendPasswordRecovery(
        phoneNumber: phone,
        userName: userName,
        password: newPassword,
        isActivated: true,
      );

      _isLoading = false;
      notifyListeners();
      return {
        'success': true,
        'message': 'New password sent to your WhatsApp',
      };
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// Recover activation key using OTP verification
  Future<Map<String, dynamic>> recoverActivationKeyWithOtp({
    required String email,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Find user
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (user['email'] == email) {
          foundUser = user as Map<String, dynamic>;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'User not found';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      final phone = foundUser['phone'] ?? '';

      // 2. Verify OTP
      final verified = _whatsAppService.verifyOtp(
        phoneNumber: phone,
        otp: otp,
      );

      if (!verified) {
        _errorMessage = 'Invalid or expired OTP';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'INVALID_OTP'};
      }

      // 3. Get activation key
      final activationKey = await _getActivationFileFromGitHub(email);
      if (activationKey == null) {
        _errorMessage = 'No activation key found for this account';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'NO_ACTIVATION_KEY'};
      }

      // 4. Send activation key via WhatsApp
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;
      await _whatsAppService.sendActivationKey(
        phoneNumber: phone,
        userName: userName,
        activationKey: activationKey,
      );

      _isLoading = false;
      notifyListeners();
      return {
        'success': true,
        'message': 'Activation key sent to your WhatsApp',
        'activationKey': activationKey,
      };
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// Renew activation key using OTP verification
  Future<Map<String, dynamic>> renewActivationKeyWithOtp({
    required String email,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Find user
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (user['email'] == email) {
          foundUser = user as Map<String, dynamic>;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'User not found';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      final phone = foundUser['phone'] ?? '';

      // 2. Verify OTP
      final verified = _whatsAppService.verifyOtp(
        phoneNumber: phone,
        otp: otp,
      );

      if (!verified) {
        _errorMessage = 'Invalid or expired OTP';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'INVALID_OTP'};
      }

      // 3. Delete old activation file
      await _deleteActivationFileFromGitHub(email);

      // 4. Generate new activation key
      final newActivationKey = generateActivationCode();

      // 5. Create new activation file
      await _createActivationFileOnGitHub(email, newActivationKey);

      // 6. Reset HWID to allow new device binding
      await _updateUserHWID(email, '');

      // 7. Send new activation key via WhatsApp
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;
      await _whatsAppService.sendActivationKeyRenewal(
        phoneNumber: phone,
        userName: userName,
        activationKey: newActivationKey,
      );

      _isLoading = false;
      notifyListeners();
      return {
        'success': true,
        'message': 'New activation key sent to your WhatsApp',
        'activationKey': newActivationKey,
      };
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// Change email using OTP verification
  Future<Map<String, dynamic>> changeEmailWithOtp({
    required String currentEmail,
    required String newEmail,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Find user
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      int userIndex = -1;
      for (var i = 0; i < usersData.length; i++) {
        if (usersData[i]['email'] == currentEmail) {
          foundUser = usersData[i] as Map<String, dynamic>;
          userIndex = i;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'User not found';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      final phone = foundUser['phone'] ?? '';

      // 2. Verify OTP
      final verified = _whatsAppService.verifyOtp(
        phoneNumber: phone,
        otp: otp,
      );

      if (!verified) {
        _errorMessage = 'Invalid or expired OTP';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'INVALID_OTP'};
      }

      // 3. Check if new email already exists
      for (var user in usersData) {
        if (user['email'] == newEmail) {
          _errorMessage = 'Email already in use';
          _isLoading = false;
          notifyListeners();
          return {'success': false, 'error': 'EMAIL_EXISTS'};
        }
      }

      // 4. Get old activation file
      final activationCode = await _getActivationFileFromGitHub(currentEmail);

      // 5. Update user email in users.json
      usersData[userIndex]['email'] = newEmail;

      final apiUrl = _getGitHubApiUrl(_usersFile);
      final getResponse = await HttpClientService.client.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode != 200) {
        _errorMessage = 'Failed to fetch users data';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'FETCH_FAILED'};
      }

      final fileData = json.decode(getResponse.body);
      final sha = fileData['sha'];

      final newContent = base64Encode(utf8.encode(json.encode(usersData)));

      final putResponse = await HttpClientService.client.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': 'Update email from $currentEmail to $newEmail',
          'content': newContent,
          'sha': sha,
          'branch': _githubBranch,
        }),
      );

      if (putResponse.statusCode != 200 && putResponse.statusCode != 201) {
        _errorMessage = 'Failed to update email';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'UPDATE_FAILED'};
      }

      // 6. Move activation file to new email
      if (activationCode != null) {
        await _deleteActivationFileFromGitHub(currentEmail);
        await _createActivationFileOnGitHub(newEmail, activationCode);
      }

      // 7. Send confirmation via WhatsApp
      final userName =
          foundUser['name'] ?? foundUser['username'] ?? currentEmail;
      await _whatsAppService.sendEmailChangeConfirmation(
        phoneNumber: phone,
        userName: userName,
        oldEmail: currentEmail,
        newEmail: newEmail,
      );

      _isLoading = false;
      notifyListeners();
      return {
        'success': true,
        'message': 'Email changed successfully',
        'newEmail': newEmail,
      };
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }

  /// Change password using OTP verification
  Future<Map<String, dynamic>> changePasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Find user
      final usersData = await _getUsersFromGitHub();
      if (usersData == null) {
        _errorMessage = 'Failed to connect to server';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'CONNECTION_FAILED'};
      }

      Map<String, dynamic>? foundUser;
      for (var user in usersData) {
        if (user['email'] == email) {
          foundUser = user as Map<String, dynamic>;
          break;
        }
      }

      if (foundUser == null) {
        _errorMessage = 'User not found';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'USER_NOT_FOUND'};
      }

      final phone = foundUser['phone'] ?? '';

      // 2. Verify OTP
      final verified = _whatsAppService.verifyOtp(
        phoneNumber: phone,
        otp: otp,
      );

      if (!verified) {
        _errorMessage = 'Invalid or expired OTP';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'INVALID_OTP'};
      }

      // 3. Update password
      final newPasswordHash =
          sha256.convert(utf8.encode(newPassword)).toString();
      final success = await _updateUserPassword(email, newPasswordHash);

      if (!success) {
        _errorMessage = 'Failed to update password';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'error': 'UPDATE_FAILED'};
      }

      // 4. Send confirmation via WhatsApp
      final userName = foundUser['name'] ?? foundUser['username'] ?? email;
      await _whatsAppService.sendPasswordChangeConfirmation(
        phoneNumber: phone,
        userName: userName,
      );

      _isLoading = false;
      notifyListeners();
      return {
        'success': true,
        'message': 'Password changed successfully',
      };
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'UNKNOWN'};
    }
  }
}
