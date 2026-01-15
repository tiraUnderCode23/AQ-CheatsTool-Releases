import 'dart:convert';
import 'package:http/http.dart' as http;

/// Gemini AI Service for Welcome Light HEX Generation
/// API Key: AIzaSyDZjR_b4wyMiEhEHUN_0F8161uurxvnpww
class GeminiService {
  static const String _apiKey = 'AIzaSyDZjR_b4wyMiEhEHUN_0F8161uurxvnpww';
  // Updated to gemini-2.0-flash (gemini-pro is retired as of December 2025)
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// System prompt with training data for Welcome Light HEX generation
  static const String _systemPrompt = '''
You are an expert BMW Welcome Light HEX code generator. You generate HEX sequences for BMW headlight welcome animations.

TECHNICAL KNOWLEDGE:
- Welcome lights use FLM2 (Front Light Module 2) coding
- Each side (Links=Left, Rechts=Right) has separate Staging1_Data and Staging2_Data
- HEX values control LED brightness (00-FF) and timing (in 10ms increments)
- Format: Brightness pairs with duration, comma separated

BRIGHTNESS VALUES:
- 00 = 0% (off)
- 40 = 25%
- 80 = 50%
- BF = 75%
- FF = 100%

DURATION VALUES (in 10ms):
- 0A = 100ms
- 14 = 200ms
- 1E = 300ms
- 32 = 500ms
- 4B = 750ms
- 64 = 1000ms

LIGHT MODULE NAMES (LM):
- LM01-LM12 are different light elements
- Lowbeam (02, 03, 04) = Main headlight LEDs
- Highbeam (06, 07) = High beam LEDs
- DRL (09, 0A) = Daytime Running Lights

EXAMPLE SEQUENCES:
1. Smooth Fade In (0 to 100% over 1 second):
   00, 0A, 20, 0A, 40, 0A, 60, 0A, 80, 0A, A0, 0A, C0, 0A, FF, 0A

2. Pulse Effect:
   FF, 14, 00, 14, FF, 14, 00, 14, FF, 32

3. Sequential Build Up:
   20, 14, 40, 14, 60, 14, 80, 14, A0, 14, C0, 14, FF, 32

4. Breathing Effect:
   00, 14, 20, 14, 40, 14, 60, 14, 80, 14, A0, 14, C0, 14, FF, 32, C0, 14, A0, 14, 80, 14, 60, 14, 40, 14, 20, 14, 00, 32

5. Wave Pattern:
   FF, 0A, C0, 0A, 80, 0A, 40, 0A, 80, 0A, C0, 0A, FF, 0A

REAL BMW DATA EXAMPLES:
Initial Version - Links Staging1:
00, 4B, 01, 0C, 02, 0C, 04, 0C, 06, 0C, 09, 0C, 0D, 0C, 11, 0C, 17, 0C, 1C, 0C, 23, 0C, 2A, 0C, 32, 0C, 3B, 0C, 45, 0C, 51, 0C, 5D, 0C, 6B, 0C, 7A, 0C, 8A, 0C, 9C, 0C, AE, 0C, C3, 0C, DA, 0C, F3, 0C, FE, 2F

V2 Flasher Enhanced:
00, 32, 10, 0A, 20, 0A, 30, 0A, 40, 0A, 50, 0A, 60, 0A, 70, 0A, 80, 0A, 90, 0A, A0, 0A, B0, 0A, C0, 0A, D0, 0A, E0, 0A, F0, 0A, FF, 64

AQ///bimmer Special:
00, 14, FF, 0A, 00, 0A, FF, 0A, 00, 14, 40, 14, 80, 14, C0, 14, FF, 32, FF, 64

When generating sequences, consider:
1. Total animation time (usually 1-3 seconds)
2. Smooth transitions between brightness levels
3. Visual effect description
4. Both Links (left) and Rechts (right) should be similar or mirrored

OUTPUT FORMAT:
Return a JSON object with this structure:
{
  "links_staging1": "HEX, values, here",
  "links_staging2": "HEX, values, here",
  "rechts_staging1": "HEX, values, here",
  "rechts_staging2": "HEX, values, here",
  "description": "Brief description of the effect",
  "steps": [
    {"brightness": "100%", "duration": "200ms"},
    ...
  ]
}
''';

  /// Generate Welcome Light HEX sequence from description
  static Future<WelcomeLightResult> generateWelcomeLight(
      String userPrompt) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      '$_systemPrompt\n\nUser Request: $userPrompt\n\nGenerate the HEX sequence and return as JSON:'
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

        // Extract JSON from response
        final jsonMatch =
            RegExp(r'\{[\s\S]*\}', multiLine: true).firstMatch(text);
        if (jsonMatch != null) {
          final jsonData = jsonDecode(jsonMatch.group(0)!);
          return WelcomeLightResult(
            linksStaging1: jsonData['links_staging1'] ?? '',
            linksStaging2: jsonData['links_staging2'] ?? '',
            rechtsStaging1: jsonData['rechts_staging1'] ?? '',
            rechtsStaging2: jsonData['rechts_staging2'] ?? '',
            description: jsonData['description'] ?? '',
            steps: (jsonData['steps'] as List?)
                    ?.map((s) => WelcomeLightStep(
                          brightness: s['brightness'] ?? '100%',
                          duration: s['duration'] ?? '200ms',
                        ))
                    .toList() ??
                [],
            success: true,
          );
        }
      }

      return WelcomeLightResult(
        success: false,
        error: 'Failed to parse AI response',
      );
    } catch (e) {
      return WelcomeLightResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Generate with specific pattern preset
  static Future<WelcomeLightResult> generateFromPreset(String preset) async {
    final presetPrompts = {
      'Smooth Fade':
          'Create a smooth fade in effect from 0% to 100% brightness over 1.5 seconds, then hold at 100% for 0.5 seconds',
      'Pulse Effect':
          'Create a pulsing effect that goes from 100% to 0% and back 3 times quickly, ending at 100%',
      'Wave Pattern':
          'Create a wave pattern that smoothly oscillates between 40% and 100% brightness in a gentle wave motion',
      'Strobe':
          'Create a strobe effect with rapid on/off flashing at maximum brightness for 0.5 seconds, then smooth fade to 100%',
      'Breathing':
          'Create a breathing effect that slowly fades in and out like a calm breath, with smooth transitions',
      'Sequential':
          'Create a sequential build-up effect where brightness increases in clear steps from 0% to 100%',
      'AQ Special':
          'Create an exciting AQ///bimmer signature effect with quick flash, pause, then smooth build-up to 100%',
    };

    return generateWelcomeLight(
        presetPrompts[preset] ?? 'Create a smooth welcome light effect');
  }

  /// Validate HEX sequence format
  static bool validateHexSequence(String hexSequence) {
    if (hexSequence.isEmpty) return false;

    final hexValues = hexSequence.split(',').map((v) => v.trim()).toList();
    if (hexValues.length < 2) return false;

    // Check if all values are valid HEX (00-FF)
    for (final value in hexValues) {
      if (!RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(value)) {
        return false;
      }
    }

    return true;
  }

  /// Convert brightness percentage to HEX
  static String brightnessToHex(int percentage) {
    final value = (percentage * 255 / 100).round();
    return value.toRadixString(16).toUpperCase().padLeft(2, '0');
  }

  /// Convert duration in ms to HEX (in 10ms increments)
  static String durationToHex(int milliseconds) {
    final value = (milliseconds / 10).round();
    return value.toRadixString(16).toUpperCase().padLeft(2, '0');
  }
}

/// Result from Gemini AI generation
class WelcomeLightResult {
  final String linksStaging1;
  final String linksStaging2;
  final String rechtsStaging1;
  final String rechtsStaging2;
  final String description;
  final List<WelcomeLightStep> steps;
  final bool success;
  final String? error;

  WelcomeLightResult({
    this.linksStaging1 = '',
    this.linksStaging2 = '',
    this.rechtsStaging1 = '',
    this.rechtsStaging2 = '',
    this.description = '',
    this.steps = const [],
    this.success = false,
    this.error,
  });
}

/// Single step in the welcome light sequence
class WelcomeLightStep {
  final String brightness;
  final String duration;

  WelcomeLightStep({
    required this.brightness,
    required this.duration,
  });
}
