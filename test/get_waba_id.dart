// Get WABA ID from Phone Number
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('🔍 Getting WABA ID from Phone Number');
  print('═══════════════════════════════════════════════════\n');

  // Get phone number with account info
  print('Getting account info from phone number...');
  final url1 =
      '$baseUrl/$apiVersion/$phoneNumberId?fields=whatsapp_business_account';

  try {
    final response = await http.get(
      Uri.parse(url1),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print('Status: ${response.statusCode}');
    final data = json.decode(response.body);
    print('Response: ${const JsonEncoder.withIndent('  ').convert(data)}');

    if (response.statusCode == 200) {
      final wabaId = data['whatsapp_business_account']?['id'];
      if (wabaId != null) {
        print('\n✅ WABA ID found: $wabaId');

        // Now get message templates
        print('\n═══════════════════════════════════════════════════');
        print('📋 Getting Message Templates');
        print('═══════════════════════════════════════════════════\n');

        final templatesUrl = '$baseUrl/$apiVersion/$wabaId/message_templates';
        final templatesResponse = await http.get(
          Uri.parse(templatesUrl),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        print('Templates Status: ${templatesResponse.statusCode}');
        final templatesData = json.decode(templatesResponse.body);
        print(
            'Templates: ${const JsonEncoder.withIndent('  ').convert(templatesData)}');

        if (templatesResponse.statusCode == 200) {
          final templates = templatesData['data'] as List?;
          if (templates != null && templates.isNotEmpty) {
            print('\n═══════════════════════════════════════════════════');
            print('📝 Available Templates (${templates.length}):');
            print('═══════════════════════════════════════════════════');
            for (var template in templates) {
              print(
                  '  - ${template['name']} (${template['status']}) - ${template['category']}');
            }
          } else {
            print('\n⚠️ No templates found!');
            print('You need to create a message template at:');
            print(
                'https://business.facebook.com/wa/manage/message-templates/?waba_id=$wabaId');
          }
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
