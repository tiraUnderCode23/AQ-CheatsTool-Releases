import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'http_client_service.dart';

/// WhatsApp Business API Service for OTP verification and notifications
/// Supports sending OTP codes and password recovery messages
/// Uses professional CTA (Call-to-Action) templates with interactive buttons
///
/// This service uses HttpClientService for robust SSL handling on Windows
class WhatsAppBusinessApiService {
  // WhatsApp Business API Configuration
  // Your actual WhatsApp Business API credentials
  static const String _phoneNumberId = '580027788531040';
  static const String _accessToken =
      'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
  static const String _apiVersion = 'v22.0';
  static const String _baseUrl = 'https://graph.facebook.com';
  static const String _websiteUrl = 'https://aqbimmer.com';

  /// WhatsApp Business display phone number for users to initiate conversation
  static const String businessPhoneNumber = '+972524864281';

  // API Status tracking
  static String? _lastApiError;
  static DateTime? _lastApiCheck;
  static bool? _isTokenValid;

  // Check if API is configured
  static bool get isConfigured =>
      _phoneNumberId.isNotEmpty && _accessToken.isNotEmpty;

  // Development mode - when API is not configured
  static bool get isDevelopmentMode => !isConfigured;

  // Get last API error
  static String? get lastApiError => _lastApiError;

  // Get token validity status
  static bool? get isTokenValid => _isTokenValid;

  // OTP Configuration
  static const int _otpLength = 5;
  static const int _otpExpiryMinutes = 5;

  // Device switch cooldown (24 hours in milliseconds)
  static const int _deviceSwitchCooldownMs = 24 * 60 * 60 * 1000;

  // Singleton instance
  static final WhatsAppBusinessApiService _instance =
      WhatsAppBusinessApiService._internal();
  factory WhatsAppBusinessApiService() => _instance;
  WhatsAppBusinessApiService._internal();

  // Store pending OTPs in memory (in production, use secure storage)
  final Map<String, _OtpData> _pendingOtps = {};

  /// Verify WhatsApp Business API token validity
  /// Returns true if token is valid, false otherwise
  /// Uses HttpClientService for robust SSL handling on Windows
  Future<bool> verifyApiToken() async {
    try {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('[WhatsApp] 🔍 Verifying API Token...');

      if (!isConfigured) {
        debugPrint('[WhatsApp] ❌ API not configured - running in dev mode');
        _lastApiError = 'API not configured';
        _isTokenValid = false;
        return false;
      }

      // Check internet connectivity first
      if (!await HttpClientService.hasInternetConnection()) {
        debugPrint('[WhatsApp] ❌ No internet connection');
        _lastApiError = 'No internet connection';
        _isTokenValid = false;
        debugPrint('═══════════════════════════════════════════════════');
        return false;
      }

      // Test the token by getting phone number info
      final url = '$_baseUrl/$_apiVersion/$_phoneNumberId';

      final response = await HttpClientService.get(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
        timeout: const Duration(seconds: 15),
      );

      _lastApiCheck = DateTime.now();

      if (response == null) {
        _lastApiError = 'Network request failed';
        _isTokenValid = false;
        debugPrint('[WhatsApp] ❌ Token verification failed - no response');
        debugPrint('═══════════════════════════════════════════════════');
        return false;
      }

      debugPrint('[WhatsApp] Token check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        _isTokenValid = true;
        _lastApiError = null;
        debugPrint('[WhatsApp] ✅ Token is VALID');
        debugPrint('═══════════════════════════════════════════════════');
        return true;
      } else {
        final body = json.decode(response.body);
        final error = body['error'];
        _lastApiError =
            error?['message'] ?? 'Unknown error: ${response.statusCode}';
        _isTokenValid = false;

        debugPrint('[WhatsApp] ❌ Token is INVALID');
        debugPrint('[WhatsApp] Error Code: ${error?['code']}');
        debugPrint('[WhatsApp] Error Type: ${error?['type']}');
        debugPrint('[WhatsApp] Error Message: $_lastApiError');
        debugPrint('═══════════════════════════════════════════════════');

        // Check for common errors
        if (error?['code'] == 190) {
          debugPrint(
              '[WhatsApp] ⚠️ ACCESS TOKEN EXPIRED - Please generate a new token from Meta Business Suite');
        } else if (error?['code'] == 100) {
          debugPrint('[WhatsApp] ⚠️ Invalid Phone Number ID');
        }

        return false;
      }
    } on TimeoutException {
      _lastApiError = 'Request timed out';
      _isTokenValid = false;
      debugPrint('[WhatsApp] ❌ Token verification timed out');
      debugPrint('═══════════════════════════════════════════════════');
      return false;
    } on SocketException catch (e) {
      _lastApiError = 'Network error: $e';
      _isTokenValid = false;
      debugPrint('[WhatsApp] ❌ Network error during verification: $e');
      debugPrint('═══════════════════════════════════════════════════');
      return false;
    } catch (e) {
      _lastApiError = 'Connection error: $e';
      _isTokenValid = false;
      debugPrint('[WhatsApp] ❌ Token verification failed: $e');
      debugPrint('═══════════════════════════════════════════════════');
      return false;
    }
  }

  /// Get detailed API status for debugging
  Map<String, dynamic> getApiStatus() {
    return {
      'isConfigured': isConfigured,
      'isDevelopmentMode': isDevelopmentMode,
      'isTokenValid': _isTokenValid,
      'lastError': _lastApiError,
      'lastCheck': _lastApiCheck?.toIso8601String(),
      'phoneNumberId': _phoneNumberId.isNotEmpty
          ? '${_phoneNumberId.substring(0, 4)}...'
          : 'Not set',
      'apiVersion': _apiVersion,
    };
  }

  /// Generate a 5-digit OTP code
  String generateOtp() {
    final random = Random.secure();
    return List.generate(_otpLength, (_) => random.nextInt(10)).join();
  }

  /// Send OTP to phone number for verification during registration
  /// Returns the generated OTP if successful, null if failed
  /// Uses CTA template with copy button
  Future<String?> sendOtpForRegistration({
    required String phoneNumber,
    required String userName,
  }) async {
    try {
      final otp = generateOtp();
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('[WhatsApp] 📤 Attempting to send OTP...');
      debugPrint('[WhatsApp] Phone: $formattedPhone');
      debugPrint('[WhatsApp] User: $userName');

      // Store OTP with expiry
      _pendingOtps[formattedPhone] = _OtpData(
        otp: otp,
        expiresAt:
            DateTime.now().add(const Duration(minutes: _otpExpiryMinutes)),
        type: OtpType.registration,
      );

      // Development mode - just log and return success
      if (isDevelopmentMode) {
        debugPrint('═══════════════════════════════════════════════════');
        debugPrint('📱 [DEV MODE] OTP for $formattedPhone: $otp');
        debugPrint('👤 User: $userName');
        debugPrint('⏰ Expires in $_otpExpiryMinutes minutes');
        debugPrint('═══════════════════════════════════════════════════');
        return otp;
      }

      // Verify token before sending
      if (_isTokenValid == null) {
        debugPrint('[WhatsApp] First time - verifying token...');
        await verifyApiToken();
      }

      if (_isTokenValid == false) {
        debugPrint('[WhatsApp] ⚠️ Token invalid - using fallback mode');
        debugPrint('📱 [FALLBACK] OTP for $formattedPhone: $otp');
        debugPrint('⚠️ WhatsApp message NOT sent - Token expired or invalid');
        debugPrint('⚠️ Error: $_lastApiError');
        debugPrint('═══════════════════════════════════════════════════');
        // Still return OTP for manual verification
        return otp;
      }

      // Send via WhatsApp Business API - Use multiple methods
      // Tries: 1. Interactive message, 2. Text message, 3. Template
      bool success = await _sendOtpMessage(
        phoneNumber: formattedPhone,
        otp: otp,
        userName: userName,
      );

      if (success) {
        debugPrint('[WhatsApp] ✅ OTP sent successfully to $formattedPhone');
        debugPrint('═══════════════════════════════════════════════════');
        return otp;
      } else {
        debugPrint(
            '[WhatsApp] ❌ API failed - returning OTP for manual verification');
        debugPrint('📱 OTP for $formattedPhone: $otp');
        debugPrint('⚠️ Last Error: $_lastApiError');
        debugPrint('═══════════════════════════════════════════════════');
        return otp;
      }
    } catch (e) {
      debugPrint('[WhatsApp] ❌ Error sending OTP: $e');
      debugPrint('═══════════════════════════════════════════════════');
      _lastApiError = e.toString();
      return null;
    }
  }

  /// Verify OTP code
  bool verifyOtp({
    required String phoneNumber,
    required String otp,
  }) {
    final formattedPhone = _formatPhoneNumber(phoneNumber);
    final otpData = _pendingOtps[formattedPhone];

    if (otpData == null) {
      debugPrint('[WhatsApp] No OTP found for $formattedPhone');
      return false;
    }

    if (DateTime.now().isAfter(otpData.expiresAt)) {
      debugPrint('[WhatsApp] OTP expired for $formattedPhone');
      _pendingOtps.remove(formattedPhone);
      return false;
    }

    if (otpData.otp == otp) {
      debugPrint('[WhatsApp] OTP verified for $formattedPhone');
      _pendingOtps.remove(formattedPhone);
      return true;
    }

    debugPrint('[WhatsApp] Invalid OTP for $formattedPhone');
    return false;
  }

  /// Send password recovery to activated account via WhatsApp
  /// Only works for activated accounts - Uses simple text for better delivery
  Future<bool> sendPasswordRecovery({
    required String phoneNumber,
    required String userName,
    required String password,
    required bool isActivated,
  }) async {
    if (!isActivated) {
      debugPrint('[WhatsApp] Cannot send password - account not activated');
      return false;
    }

    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final message = '''🔑 *AQ CheatsTool - Password Recovery*

Hello \`$userName\`,

Your password recovery was requested.

Your Password:
\`$password\`

⚠️ Important Notes:
• Please change your password after logging in
• Do not share this information with anyone

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending password recovery: $e');
      return false;
    }
  }

  /// Send activation key directly via WhatsApp - Uses simple text for better delivery
  Future<bool> sendActivationKey({
    required String phoneNumber,
    required String userName,
    required String activationKey,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final message = '''🎉 *AQ CheatsTool - Account Activated*

Hello \`$userName\`,

Your account has been successfully activated! 🎉

Activation Key:
\`$activationKey\`

📱 You can now use this key to activate the program on your device.

⚠️ Important Notes:
• Activation key is linked to one device only
• Do not share this key with anyone

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending activation key: $e');
      return false;
    }
  }

  /// Send device switch notification - Security alert
  Future<bool> sendDeviceSwitchNotification({
    required String phoneNumber,
    required String userName,
    required String newDeviceId,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      final shortDeviceId = newDeviceId.length > 8
          ? '${newDeviceId.substring(0, 8)}...'
          : newDeviceId;

      final message = '''⚠️ *AQ CheatsTool - Security Alert*

Hello \`$userName\`,

Your account has been switched to a new device.

🖥️ New Device ID: \`$shortDeviceId\`

⚠️ Important Notes:
• If you did not perform this action, please contact us immediately!
• Contact: +972528180757

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending device switch notification: $e');
      return false;
    }
  }

  /// Check if device switch is allowed (24 hour cooldown)
  Future<bool> canSwitchDevice(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSwitchKey = 'last_device_switch_$email';
      final lastSwitchTime = prefs.getInt(lastSwitchKey);

      if (lastSwitchTime == null) {
        return true;
      }

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final timeSinceLastSwitch = currentTime - lastSwitchTime;

      return timeSinceLastSwitch >= _deviceSwitchCooldownMs;
    } catch (e) {
      debugPrint('[WhatsApp] Error checking device switch: $e');
      return false;
    }
  }

  /// Get remaining time until device switch is allowed
  Future<Duration> getDeviceSwitchCooldownRemaining(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSwitchKey = 'last_device_switch_$email';
      final lastSwitchTime = prefs.getInt(lastSwitchKey);

      if (lastSwitchTime == null) {
        return Duration.zero;
      }

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final timeSinceLastSwitch = currentTime - lastSwitchTime;
      final remainingMs = _deviceSwitchCooldownMs - timeSinceLastSwitch;

      return remainingMs > 0
          ? Duration(milliseconds: remainingMs)
          : Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Record device switch time
  Future<void> recordDeviceSwitch(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSwitchKey = 'last_device_switch_$email';
      await prefs.setInt(lastSwitchKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[WhatsApp] Error recording device switch: $e');
    }
  }

  /// Format phone number to international format
  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Ensure it starts with country code
    if (!cleaned.startsWith('+')) {
      // Assume it's a local number, add default country code
      if (cleaned.startsWith('0')) {
        cleaned = '+972${cleaned.substring(1)}'; // Israel default
      } else {
        cleaned = '+$cleaned';
      }
    }

    return cleaned;
  }

  // List of template names to try (in order of preference)
  // IMPORTANT: Only use APPROVED templates from Meta Business Suite
  // Current approved templates: aq_account_notification
  static const List<String> _otpTemplateNames = [
    'aq_account_notification', // APPROVED - Has {{1}} parameter for OTP
  ];

  /// Send OTP using multiple methods
  /// 1. First tries interactive message (works if 24h window is open)
  /// 2. Then tries template message (for users who haven't messaged)
  /// Returns true if any method succeeds
  Future<bool> _sendOtpMessage({
    required String phoneNumber,
    required String otp,
    required String userName,
  }) async {
    debugPrint('[WhatsApp] 📤 Sending OTP...');
    debugPrint('[WhatsApp] Phone: $phoneNumber');

    // Method 1: Try interactive message first (better UX)
    final interactiveResult = await _sendInteractiveOtp(
      phoneNumber: phoneNumber,
      otp: otp,
    );
    if (interactiveResult) return true;

    // Method 2: Try text message
    final textResult = await _sendTextOtp(
      phoneNumber: phoneNumber,
      otp: otp,
    );
    if (textResult) return true;

    // Method 3: Fall back to template
    return await _sendOtpWithTemplate(
      phoneNumber: phoneNumber,
      otp: otp,
      userName: userName,
    );
  }

  /// Send OTP as interactive message with button
  Future<bool> _sendInteractiveOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    const url = '$_baseUrl/$_apiVersion/$_phoneNumberId/messages';

    try {
      debugPrint('[WhatsApp] Trying interactive message...');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'messaging_product': 'whatsapp',
          'recipient_type': 'individual',
          'to': phoneNumber.replaceAll('+', ''),
          'type': 'interactive',
          'interactive': {
            'type': 'button',
            'body': {
              'text':
                  '🔐 *AQ///bimmer Verification*\n\nYour code is: *$otp*\n\n⏱️ Expires in 5 minutes'
            },
            'action': {
              'buttons': [
                {
                  'type': 'reply',
                  'reply': {'id': 'copy_code', 'title': '📋 Code: $otp'}
                }
              ]
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[WhatsApp] ✅ Interactive OTP sent successfully');
        return true;
      }

      final error = json.decode(response.body)['error'];
      debugPrint('[WhatsApp] Interactive failed: ${error?['message']}');
      return false;
    } catch (e) {
      debugPrint('[WhatsApp] Interactive error: $e');
      return false;
    }
  }

  /// Send OTP as plain text message
  Future<bool> _sendTextOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    const url = '$_baseUrl/$_apiVersion/$_phoneNumberId/messages';

    try {
      debugPrint('[WhatsApp] Trying text message...');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'messaging_product': 'whatsapp',
          'recipient_type': 'individual',
          'to': phoneNumber.replaceAll('+', ''),
          'type': 'text',
          'text': {
            'preview_url': false,
            'body':
                '🔐 *AQ///bimmer Verification*\n\nYour code is: *$otp*\n\n⏱️ Expires in 5 minutes\n⚠️ Do not share this code'
          }
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[WhatsApp] ✅ Text OTP sent successfully');
        return true;
      }

      final error = json.decode(response.body)['error'];
      debugPrint('[WhatsApp] Text failed: ${error?['message']}');
      return false;
    } catch (e) {
      debugPrint('[WhatsApp] Text error: $e');
      return false;
    }
  }

  /// Send OTP using WhatsApp Template (fallback)
  /// This is required for sending messages to users who haven't messaged in 24 hours
  /// Tries multiple template names until one works
  Future<bool> _sendOtpWithTemplate({
    required String phoneNumber,
    required String otp,
    required String userName,
  }) async {
    const url = '$_baseUrl/$_apiVersion/$_phoneNumberId/messages';

    debugPrint('[WhatsApp] 📤 Sending OTP via Template...');

    // Try each template name until one works
    for (final templateName in _otpTemplateNames) {
      debugPrint('[WhatsApp] Trying template: $templateName');

      try {
        // Build parameters based on template type
        List<Map<String, dynamic>> bodyParameters;

        if (templateName == 'aq_account_notification') {
          // Template: "Hello {{1}}, this is a notification from AQ///bimmer Tools..."
          // NOTE: Parameters cannot contain newlines, tabs, or 4+ consecutive spaces
          bodyParameters = [
            {
              'type': 'text',
              'text': '🔐 Your verification code is: *$otp* (expires in 5 min)'
            }
          ];
        } else if (templateName == 'aq_welcome_message') {
          // This template has no parameters, skip body components
          bodyParameters = [];
        } else {
          // Default: just send the OTP
          bodyParameters = [
            {'type': 'text', 'text': otp}
          ];
        }

        // Build request body
        final Map<String, dynamic> templateData = {
          'name': templateName,
          'language': {'code': 'en'},
        };

        // Add components only if we have parameters
        if (bodyParameters.isNotEmpty) {
          templateData['components'] = [
            {'type': 'body', 'parameters': bodyParameters}
          ];
        }

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'messaging_product': 'whatsapp',
            'recipient_type': 'individual',
            'to': phoneNumber.replaceAll('+', ''),
            'type': 'template',
            'template': templateData,
          }),
        );

        debugPrint(
            '[WhatsApp] Template "$templateName" response: ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint(
              '[WhatsApp] ✅ OTP sent via template "$templateName" successfully');
          return true;
        }

        // Parse error
        final errorBody = json.decode(response.body);
        final error = errorBody['error'];
        final errorCode = error?['code'];

        // If template not found, try next one
        if (errorCode == 132001) {
          debugPrint(
              '[WhatsApp] Template "$templateName" not found, trying next...');
          continue;
        }

        // If token expired, stop trying
        if (errorCode == 190) {
          _isTokenValid = false;
          _lastApiError = 'Access token expired';
          debugPrint('[WhatsApp] ⚠️ ACCESS TOKEN EXPIRED!');
          return false;
        }

        // Other errors, log and try next
        _lastApiError = error?['message'] ?? 'Template error';
        debugPrint(
            '[WhatsApp] Template "$templateName" failed: $_lastApiError');
      } catch (e) {
        debugPrint('[WhatsApp] Template "$templateName" error: $e');
      }
    }

    // All templates failed
    debugPrint('[WhatsApp] ❌ All template attempts failed');
    debugPrint(
        '[WhatsApp] ⚠️ Please create an approved OTP template in Meta Business Suite:');
    debugPrint(
        '[WhatsApp] https://business.facebook.com/wa/manage/message-templates/');
    return false;
  }

  /// Send WhatsApp message using template
  Future<bool> _sendWhatsAppMessage({
    required String phoneNumber,
    required String templateName,
    required List<String> parameters,
  }) async {
    try {
      const url = '$_baseUrl/$_apiVersion/$_phoneNumberId/messages';

      final components = parameters
          .map((param) => {
                'type': 'text',
                'text': param,
              })
          .toList();

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'messaging_product': 'whatsapp',
          'to': phoneNumber.replaceAll('+', ''),
          'type': 'template',
          'template': {
            'name': templateName,
            'language': {'code': 'en'},
            'components': [
              {
                'type': 'body',
                'parameters': components,
              }
            ],
          },
        }),
      );

      debugPrint('[WhatsApp] Template response: ${response.statusCode}');
      debugPrint('[WhatsApp] Template response body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[WhatsApp] Template error: $e');
      return false;
    }
  }

  /// Send plain text WhatsApp message
  /// Uses HttpClientService for robust SSL handling on Windows
  Future<bool> _sendTextMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      const url = '$_baseUrl/$_apiVersion/$_phoneNumberId/messages';

      debugPrint('[WhatsApp] Sending to: $phoneNumber');
      debugPrint('[WhatsApp] URL: $url');

      // Check internet connectivity first
      if (!await HttpClientService.hasInternetConnection()) {
        debugPrint('[WhatsApp] ❌ No internet connection');
        _lastApiError = 'No internet connection';
        return false;
      }

      // Use HttpClientService for robust SSL handling
      final response = await HttpClientService.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: {
          'messaging_product': 'whatsapp',
          'recipient_type': 'individual',
          'to': phoneNumber.replaceAll('+', ''),
          'type': 'text',
          'text': {
            'preview_url': false,
            'body': message,
          },
        },
        timeout: const Duration(seconds: 30),
      );

      if (response == null) {
        debugPrint('[WhatsApp] ❌ Request failed - no response');
        _lastApiError =
            'Network request failed. Please check your internet connection.';
        return false;
      }

      debugPrint('[WhatsApp] Text response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[WhatsApp] ✅ Text message sent successfully');
        return true;
      }

      // Parse and log error
      try {
        final errorBody = json.decode(response.body);
        final error = errorBody['error'];
        _lastApiError = error?['message'] ?? 'Unknown error';
        final errorCode = error?['code'];

        debugPrint('[WhatsApp] ❌ Text message failed with code: $errorCode');
        debugPrint('[WhatsApp] Error: $_lastApiError');

        if (errorCode == 190) {
          _isTokenValid = false;
          debugPrint('[WhatsApp] ⚠️ ACCESS TOKEN EXPIRED!');
        }
      } catch (_) {
        debugPrint('[WhatsApp] Raw error: ${response.body}');
      }
      return false;
    } on TimeoutException {
      debugPrint('[WhatsApp] ❌ Request timed out');
      _lastApiError = 'Request timed out. Please try again.';
      return false;
    } on SocketException catch (e) {
      debugPrint('[WhatsApp] ❌ Network error: $e');
      _lastApiError = 'Network error. Please check your internet connection.';
      return false;
    } catch (e) {
      debugPrint('[WhatsApp] ❌ Text error: $e');
      _lastApiError = e.toString();
      return false;
    }
  }

  /// Send interactive CTA message with copy button and website link
  /// Professional formatted WhatsApp message with action buttons
  Future<bool> _sendInteractiveCtaMessage({
    required String phoneNumber,
    required String headerText,
    required String bodyText,
    required String footerText,
    required String copyButtonText,
    required String copyCode,
    required String websiteButtonText,
  }) async {
    try {
      const url = '$_baseUrl/$_apiVersion/$_phoneNumberId/messages';

      debugPrint('[WhatsApp] 📤 Sending CTA message to: $phoneNumber');
      debugPrint('[WhatsApp] URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'messaging_product': 'whatsapp',
          'recipient_type': 'individual',
          'to': phoneNumber.replaceAll('+', ''),
          'type': 'interactive',
          'interactive': {
            'type': 'cta_url',
            'header': {
              'type': 'text',
              'text': headerText,
            },
            'body': {
              'text': bodyText,
            },
            'footer': {
              'text': footerText,
            },
            'action': {
              'name': 'cta_url',
              'parameters': {
                'display_text': websiteButtonText,
                'url': _websiteUrl,
              },
            },
          },
        }),
      );

      debugPrint('[WhatsApp] CTA response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[WhatsApp] ✅ CTA message sent successfully');
        // Send follow-up message with copyable code
        await _sendCopyableCodeMessage(
          phoneNumber: phoneNumber,
          code: copyCode,
          label: copyButtonText,
        );
        return true;
      }

      // Parse error response
      try {
        final errorBody = json.decode(response.body);
        final error = errorBody['error'];
        _lastApiError = error?['message'] ?? 'Unknown error';
        final errorCode = error?['code'];

        debugPrint('[WhatsApp] ❌ CTA failed with code: $errorCode');
        debugPrint('[WhatsApp] Error message: $_lastApiError');
        debugPrint('[WhatsApp] Full response: ${response.body}');

        // Check for token expiry
        if (errorCode == 190) {
          _isTokenValid = false;
          debugPrint('[WhatsApp] ⚠️ ACCESS TOKEN EXPIRED!');
          debugPrint('[WhatsApp] Please generate a new token from:');
          debugPrint('[WhatsApp] https://developers.facebook.com/apps/');
        }
      } catch (_) {
        debugPrint('[WhatsApp] Raw error response: ${response.body}');
      }

      // Fallback to text message if interactive fails
      debugPrint('[WhatsApp] Falling back to text message...');
      return await _sendTextMessage(
        phoneNumber: phoneNumber,
        message: '$headerText\n\n$bodyText\n\n$footerText\n\n🔗 $_websiteUrl',
      );
    } catch (e) {
      debugPrint('[WhatsApp] ❌ CTA error: $e');
      _lastApiError = e.toString();
      return false;
    }
  }

  /// Send a message with easily copyable code
  Future<bool> _sendCopyableCodeMessage({
    required String phoneNumber,
    required String code,
    required String label,
  }) async {
    try {
      const url = '$_baseUrl/$_apiVersion/$_phoneNumberId/messages';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'messaging_product': 'whatsapp',
          'recipient_type': 'individual',
          'to': phoneNumber.replaceAll('+', ''),
          'type': 'text',
          'text': {
            'preview_url': false,
            'body': '📋 *$label*\n\n```$code```\n\n_Tap and hold to copy_',
          },
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[WhatsApp] Copy code message error: $e');
      return false;
    }
  }

  /// Clear expired OTPs (call periodically)
  void clearExpiredOtps() {
    final now = DateTime.now();
    _pendingOtps.removeWhere((_, data) => now.isAfter(data.expiresAt));
  }

  // ============================================================================
  // Professional CTA Message Templates - English Only
  // ============================================================================

  /// Send renewed activation key to activated user
  Future<bool> sendActivationKeyRenewal({
    required String phoneNumber,
    required String userName,
    required String activationKey,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final message = '''🔄 *AQ CheatsTool - Activation Key Renewal*

Hello \`$userName\`,

Your activation key has been successfully renewed! 🎉

New Activation Key:
\`$activationKey\`

📱 You can now use this key to activate the program on your device.

⚠️ Important Notes:
* Activation key is linked to one device only
* Old key has been ~cancelled~
* Do not share this key with ~anyone~

Thank you for choosing

\`AQ///cheaTool\`''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending activation key renewal: $e');
      return false;
    }
  }

  /// Send registration info to new user
  Future<bool> sendNewUserRegistrationInfo({
    required String phoneNumber,
    required String userName,
    required String email,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final message = '''📝 *AQ CheatsTool - Registration Received*

Hello \`$userName\`,

Your registration request has been received successfully! ✅

Registration Info:
• Name: *$userName*
• Email: *$email*
• Phone: *$formattedPhone*

📋 Status: *Pending Approval*

⚠️ Important Notes:
• Your request will be reviewed by admin
• You will be notified upon approval

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending registration info: $e');
      return false;
    }
  }

  /// Send password change notification
  Future<bool> sendPasswordChangeNotification({
    required String phoneNumber,
    required String userName,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      final now = DateTime.now();
      final dateStr =
          '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      final message = '''🔐 *AQ CheatsTool - Password Changed*

Hello \`$userName\`,

Your account password has been changed successfully.

📅 Date & Time: \`$dateStr\`

⚠️ Important Notes:
• If you did not perform this action, please contact us immediately!
• Contact: +972528180757

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending password change notification: $e');
      return false;
    }
  }

  /// Send account approval notification
  Future<bool> sendAccountApprovalNotification({
    required String phoneNumber,
    required String userName,
    required String activationKey,
    required String email,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final message = '''🎉 *AQ CheatsTool - Account Approved!*

Hello \`$userName\`,

We are happy to inform you that your registration has been approved! 🎉

Your Account Info:
• Email: \`$email\`
• Activation Key: \`$activationKey\`

📱 Activation Steps:
1. Open the program
2. Select "Activation Key"
3. Enter the key above
4. Enjoy the program!

⚠️ Important Notes:
• Activation key is linked to one device only
• Do not share this key with anyone

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending account approval notification: $e');
      return false;
    }
  }

  /// Send account rejection notification
  Future<bool> sendAccountRejectionNotification({
    required String phoneNumber,
    required String userName,
    String? reason,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);
      final rejectionReason = reason ?? 'Not specified';

      final message = '''❌ *AQ CheatsTool - Registration Rejected*

Hello \`$userName\`,

We regret to inform you that your registration request has been rejected.

Reason: *$rejectionReason*

⚠️ Important Notes:
• If you have any questions, please contact us
• WhatsApp: +972528180757
• Telegram: @aqbimmer

Thank you for your interest in AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending account rejection notification: $e');
      return false;
    }
  }

  /// Send phone change notification
  Future<bool> sendPhoneChangeNotification({
    required String phoneNumber,
    required String userName,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final message = '''📱 *AQ CheatsTool - Phone Updated*

Hello \`$userName\`,

Your phone number has been successfully updated to this number.

⚠️ Important Notes:
• If you did not make this change, please contact us immediately!
• Contact: +972528180757

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending phone change notification: $e');
      return false;
    }
  }

  /// Send account recovery information
  Future<bool> sendAccountRecovery({
    required String phoneNumber,
    required String userName,
    required String email,
    required String activationKey,
    required String newPassword,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final message = '''🔑 *AQ CheatsTool - Account Recovery*

Hello \`$userName\`,

Your account recovery information:

📧 Email: \`$email\`
🔐 Activation Key: \`$activationKey\`
🔑 New Password: \`$newPassword\`

⚠️ Important Notes:
• Please change your password after logging in
• Do not share this information with anyone

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending account recovery: $e');
      return false;
    }
  }

  /// Send email change confirmation
  Future<bool> sendEmailChangeConfirmation({
    required String phoneNumber,
    required String userName,
    required String oldEmail,
    required String newEmail,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final message = '''📧 *AQ CheatsTool - Email Changed*

Hello *$userName*,

Your email has been successfully changed!

Old Email: *$oldEmail*
New Email: *$newEmail*

⚠️ Important:
• Use your new email to login from now on
• If you did not make this change, contact us immediately!
• Contact: +972528180757

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending email change confirmation: $e');
      return false;
    }
  }

  /// Send password change confirmation
  Future<bool> sendPasswordChangeConfirmation({
    required String phoneNumber,
    required String userName,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      final message = '''🔐 *AQ CheatsTool - Password Changed*

Hello *$userName*,

Your password has been successfully changed!

⚠️ Important:
• Use your new password to login from now on
• If you did not make this change, contact us immediately!
• Contact: +972528180757

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

      final success = await _sendTextMessage(
        phoneNumber: formattedPhone,
        message: message,
      );

      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending password change confirmation: $e');
      return false;
    }
  }
}

/// OTP data class
class _OtpData {
  final String otp;
  final DateTime expiresAt;
  final OtpType type;

  _OtpData({
    required this.otp,
    required this.expiresAt,
    required this.type,
  });
}

/// OTP type enum
enum OtpType {
  registration,
  passwordRecovery,
  deviceVerification,
}
