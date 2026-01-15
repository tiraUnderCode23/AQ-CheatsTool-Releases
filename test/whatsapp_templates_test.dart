// WhatsApp Template Check
// Check available message templates

import 'package:http/http.dart' as http;
import 'dart:convert';

const String businessAccountId = '569217266268972'; // Your WABA ID
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('📋 WhatsApp Message Templates');
  print('═══════════════════════════════════════════════════');
  print('');

  try {
    // Get templates
    final url = '$baseUrl/$apiVersion/$businessAccountId/message_templates';

    print('Fetching templates...');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('Response Status: ${response.statusCode}');
    print('');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final templates = data['data'] as List;

      print('Found ${templates.length} templates:');
      print('');

      for (var template in templates) {
        print('─────────────────────────────────────');
        print('Name: ${template['name']}');
        print('Status: ${template['status']}');
        print('Category: ${template['category']}');
        print('Language: ${template['language']}');

        final components = template['components'] as List?;
        if (components != null) {
          for (var comp in components) {
            print(
                'Component [${comp['type']}]: ${comp['text'] ?? comp['format'] ?? ''}');
          }
        }
        print('');
      }
    } else {
      print('❌ Failed to get templates');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('═══════════════════════════════════════════════════');
}
