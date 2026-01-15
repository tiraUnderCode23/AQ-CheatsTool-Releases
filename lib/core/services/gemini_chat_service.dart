import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Gemini AI Chat Service for AQ CheatsTool
/// Provides intelligent search, navigation, and context-aware assistance
class GeminiChatService extends ChangeNotifier {
  static const String _apiKey = 'AIzaSyDZjR_b4wyMiEhEHUN_0F8161uurxvnpww';
  // Updated to gemini-2.0-flash (gemini-pro is retired as of December 2025)
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  bool _isProcessing = false;
  String? _lastResponse;
  String? _lastError;
  final List<ChatMessage> _conversationHistory = [];
  bool _isExpanded = false;

  bool get isProcessing => _isProcessing;
  String? get lastResponse => _lastResponse;
  String? get lastError => _lastError;
  List<ChatMessage> get conversationHistory => _conversationHistory;
  bool get isExpanded => _isExpanded;

  void toggleExpanded() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }

  /// Comprehensive English system prompt with full tab knowledge
  static const String _systemPrompt = '''
You are an expert BMW coding assistant for AQ CheatsTool application.
Respond ONLY in English. Be concise and helpful.

=== APPLICATION TABS (0-5) ===

TAB 0 - BMW Codings (864+ codes):
Contains complete coding database for all BMW ECUs.
ECUs include: HU_MGU, HU_NBT2, FEM_BODY, BDC_BODY, FLA_HKL, ACSM5, DSC, ICM, KAFAS2, KOMBI, ZGW, TRSVC, EGS, DME/DDE
Popular codings: CarPlay activation, Digital Speedometer, Ambient Lighting, Sport Displays, Video in Motion, Needle Sweep, Lane Departure Warning, Backup Camera retrofit
Search by: ECU name, function name, or feature description

TAB 1 - NBT EVO HDD Guide:
Step-by-step guide for HDD/SSD upgrade on NBT EVO (ID5/ID6) systems.
Steps: 1) SSH enable 2) Connect WinSCP 3) Backup 4) Clone to SSD 5) Swap 6) Verify
SSH: IP 169.254.199.119, User: root, Password: ts&SK412
Requirements: 500GB+ SSD, USB-SATA adapter, WinSCP, PuTTY
Common commands: mount -uw /, create_hdd.sh, scp

TAB 2 - Image Retrofit:
Change iDrive system images, boot animations, and UI elements.
Paths: /net/hu-omap/fs/sda0/opt/hmi/ID5/data/ro/bmw/id61/assetDB/
M Key Display, Vehicle Images (ID6), Sound Logo, ConnectedDrive Logo, Startup Animation
Unit passwords: NBT1/NBT2EVO=ts&SK412, EntryNAV=Entry0?Evo!, CIC old=cic0803, CIC new=Hm83stN
Tools: WinSCP, Feature Installer, FlashXcode ToolKit

TAB 3 - CC Messages (1227+ messages):
Check Control message database with CC-ID codes.
Format: CC-ID (hex) + Description in multiple languages
Search by: CC-ID number (e.g., 00029B), message text, category
Categories: Engine, Drivetrain, Chassis, Lighting, ADAS, Comfort, Infotainment
Each message has ISTA tutorial for E-Sys coding

TAB 4 - Welcome Light:
Configure headlight welcome/staging animations using HEX sequences.
Versions: initial, v2flasher, v3-v10, aqbimmer
Output format: Links/Rechts Staging1_Data, Staging2_Data
HEX brightness: 00=0%, 40=25%, 80=50%, BF=75%, FF=100%
Duration values: 0A=100ms, 14=200ms, 32=500ms, 64=1000ms
AI Generator creates custom sequences from descriptions
Models: G20/G80/G30/F-series support

TAB 5 - MGU Unlock:
Unlock MGU (Media Graphics Unit) with SSH and ZGW discovery.
ZGW Search: Discovers BMW gateway via UDP broadcast on port 6801
SSH: IP 169.254.199.119, Port 22, User: root
MGU Types: MGU, MGU1, MGU2, MGU3 (each with VIN, Command, File)
Quick commands: DEFSESS, PROGSESS, MOUNT RW, REBOOT
PyDiabas integration for ENET/DoIP diagnostics
11-step visual guide with terminal output

=== ACTION COMMANDS ===
Use these formats in your responses:
[ACTION:navigate:INDEX] - Navigate to tab (0-5)
[ACTION:search:INDEX:QUERY] - Search in specific tab
[ACTION:copy:TEXT] - Copy text to clipboard
[ACTION:open:URL] - Open URL in browser

=== EXAMPLES ===
Q: "How to enable CarPlay?" 
A: Go to BMW Codings tab and search for CarPlay in HU_NBT2 or HU_MGU ECU. [ACTION:navigate:0]

Q: "What is CC-ID 00029B?"
A: Let me search that CC message for you. [ACTION:search:3:00029B]

Q: "MGU unlock steps"
A: The MGU Unlock tab has a complete guide. Connect via SSH to 169.254.199.119 with root/ts&SK412. [ACTION:navigate:5]

Q: "Create breathing welcome light"
A: Use the AI Generator in Welcome Light tab. Describe "breathing effect" and it will generate HEX sequences. [ACTION:navigate:4]

=== RULES ===
1. Always respond in English
2. Be brief but informative
3. Include ONE action command when navigation/search is needed
4. Reference specific ECU names, paths, or codes when possible
5. For coding questions, mention which ECU to look in
''';

  /// Send message to Gemini and get response
  Future<GeminiChatResponse> sendMessage(String message) async {
    if (message.trim().isEmpty) {
      return GeminiChatResponse(
        text: 'Please enter a message',
        actions: [],
        success: false,
      );
    }

    _isProcessing = true;
    _lastError = null;
    notifyListeners();

    try {
      // Add user message to history
      _conversationHistory.add(ChatMessage(
        role: MessageRole.user,
        content: message,
        timestamp: DateTime.now(),
      ));

      // Build conversation context
      final context = _buildContext(message);

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': context}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
          'safetySettings': [
            {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_NONE'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_NONE'
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (text != null) {
          _lastResponse = text;

          // Add assistant response to history
          _conversationHistory.add(ChatMessage(
            role: MessageRole.assistant,
            content: text,
            timestamp: DateTime.now(),
          ));

          // Parse actions from response
          final actions = _parseActions(text);

          _isProcessing = false;
          notifyListeners();

          return GeminiChatResponse(
            text: text,
            actions: actions,
            success: true,
          );
        }
      }

      throw Exception('Invalid response: ${response.statusCode}');
    } catch (e) {
      _lastError = e.toString();
      _isProcessing = false;
      notifyListeners();

      return GeminiChatResponse(
        text: 'Sorry, connection error. Please try again later.',
        actions: [],
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Build context with system prompt and history
  String _buildContext(String currentMessage) {
    final buffer = StringBuffer();
    buffer.writeln(_systemPrompt);
    buffer.writeln('\n--- Previous Conversation ---');

    // Include last 6 messages for context
    final recentHistory = _conversationHistory.length > 12
        ? _conversationHistory.sublist(_conversationHistory.length - 12)
        : _conversationHistory;

    for (final msg in recentHistory) {
      final role = msg.role == MessageRole.user ? 'User' : 'Assistant';
      buffer.writeln('$role: ${msg.content}');
    }

    buffer.writeln('\n--- Current Message ---');
    buffer.writeln('User: $currentMessage');
    buffer.writeln('\nRespond briefly and helpfully in English:');

    return buffer.toString();
  }

  /// Parse action commands from AI response
  List<GeminiChatAction> _parseActions(String text) {
    final actions = <GeminiChatAction>[];
    final actionPattern = RegExp(r'\[ACTION:(\w+):([^\]]+)\]');
    final matches = actionPattern.allMatches(text);

    for (final match in matches) {
      final type = match.group(1);
      final params = match.group(2)?.split(':') ?? [];

      switch (type) {
        case 'navigate':
          if (params.isNotEmpty) {
            actions.add(GeminiChatAction(
              type: GeminiChatActionType.navigate,
              tabIndex: int.tryParse(params[0]),
            ));
          }
          break;
        case 'search':
          if (params.isNotEmpty) {
            actions.add(GeminiChatAction(
              type: GeminiChatActionType.search,
              tabIndex: int.tryParse(params[0]),
              query: params.length > 1 ? params.sublist(1).join(':') : null,
            ));
          }
          break;
        case 'copy':
          if (params.isNotEmpty) {
            actions.add(GeminiChatAction(
              type: GeminiChatActionType.copy,
              text: params.join(':'),
            ));
          }
          break;
        case 'open':
          if (params.isNotEmpty) {
            actions.add(GeminiChatAction(
              type: GeminiChatActionType.openUrl,
              url: params.join(':'),
            ));
          }
          break;
      }
    }

    return actions;
  }

  /// Quick navigation helper
  int getRecommendedTab(String query) {
    final lowerQuery = query.toLowerCase();

    // CC Messages keywords
    if (lowerQuery.contains('cc') ||
        lowerQuery.contains('رسالة') ||
        lowerQuery.contains('message') ||
        lowerQuery.contains('خطأ') ||
        lowerQuery.contains('error') ||
        lowerQuery.contains('check control') ||
        RegExp(r'\b[0-9a-f]{4,6}\b', caseSensitive: false).hasMatch(query)) {
      return 3; // CC Messages tab
    }

    // MGU keywords
    if (lowerQuery.contains('mgu') ||
        lowerQuery.contains('unlock') ||
        lowerQuery.contains('ssh') ||
        lowerQuery.contains('zgw') ||
        lowerQuery.contains('فتح')) {
      return 5; // MGU tab
    }

    // Coding keywords
    if (lowerQuery.contains('coding') ||
        lowerQuery.contains('كود') ||
        lowerQuery.contains('تفعيل') ||
        lowerQuery.contains('activate') ||
        lowerQuery.contains('ecu') ||
        lowerQuery.contains('carplay') ||
        lowerQuery.contains('android auto')) {
      return 0; // BMW Codings tab
    }

    // HDD keywords
    if (lowerQuery.contains('hdd') ||
        lowerQuery.contains('nbt') ||
        lowerQuery.contains('evo') ||
        lowerQuery.contains('ssd') ||
        lowerQuery.contains('قرص')) {
      return 1; // HDD tab
    }

    // Image keywords
    if (lowerQuery.contains('image') ||
        lowerQuery.contains('صورة') ||
        lowerQuery.contains('retrofit') ||
        lowerQuery.contains('idrive')) {
      return 2; // Image tab
    }

    // Welcome light keywords
    if (lowerQuery.contains('welcome') ||
        lowerQuery.contains('light') ||
        lowerQuery.contains('إضاءة') ||
        lowerQuery.contains('ترحيب') ||
        lowerQuery.contains('hex') ||
        lowerQuery.contains('staging')) {
      return 4; // Welcome Light tab
    }

    return 0; // Default to Codings
  }

  /// Suggest queries based on current tab
  List<String> getSuggestions(int currentTab) {
    switch (currentTab) {
      case 0: // BMW Codings
        return [
          'How to enable CarPlay?',
          'FEM_BODY coding options',
          'Digital Speedometer activation',
          'Backup camera retrofit codes',
        ];
      case 1: // HDD
        return [
          'SSD installation steps',
          'What size SSD do I need?',
          'How to backup data?',
          'SSH connection details',
        ];
      case 2: // Image
        return [
          'How to change images?',
          'Where are image files?',
          'Boot animation path',
          'M Key display setup',
        ];
      case 3: // CC Messages
        return [
          'What does this CC-ID mean?',
          'Search for error code',
          'Common CC messages',
          'Drivetrain errors',
        ];
      case 4: // Welcome Light
        return [
          'Create breathing effect',
          'What are HEX values?',
          'Fade in animation',
          'Sequential light pattern',
        ];
      case 5: // MGU
        return [
          'MGU unlock steps',
          'How to connect SSH?',
          'What is ZGW?',
          'Mount filesystem commands',
        ];
      default:
        return ['Help', 'How to use this app?'];
    }
  }

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
    _lastResponse = null;
    _lastError = null;
    notifyListeners();
  }
}

/// Chat message model
class ChatMessage {
  final MessageRole role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

enum MessageRole { user, assistant }

/// Response from Gemini AI Chat
class GeminiChatResponse {
  final String text;
  final List<GeminiChatAction> actions;
  final bool success;
  final String? error;

  GeminiChatResponse({
    required this.text,
    required this.actions,
    required this.success,
    this.error,
  });

  /// Get clean text without action tags
  String get cleanText {
    return text.replaceAll(RegExp(r'\[ACTION:[^\]]+\]'), '').trim();
  }
}

/// Action command from AI Chat
class GeminiChatAction {
  final GeminiChatActionType type;
  final int? tabIndex;
  final String? query;
  final String? text;
  final String? url;

  GeminiChatAction({
    required this.type,
    this.tabIndex,
    this.query,
    this.text,
    this.url,
  });
}

enum GeminiChatActionType {
  navigate,
  search,
  copy,
  openUrl,
}
