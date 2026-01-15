// Get Message Templates from WABA
import 'package:http/http.dart' as http;
import 'dart:convert';

const String wabaId = '576625715530014'; // AQ///bimmer WABA
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('Getting Message Templates from WABA: $wabaId\n');
  print('=' * 60);

  // Get all templates
  print('Fetching templates...');
  final url = '$baseUrl/$apiVersion/$wabaId/message_templates';

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print('Status: ${response.statusCode}');
    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      final templates = data['data'] as List?;

      if (templates != null && templates.isNotEmpty) {
        print('\nFound ${templates.length} template(s):\n');
        print('=' * 60);

        for (var template in templates) {
          print('Name: ${template['name']}');
          print('Status: ${template['status']}');
          print('Category: ${template['category']}');
          print('Language: ${template['language']}');
          print('ID: ${template['id']}');

          // Print components
          final components = template['components'] as List?;
          if (components != null) {
            print('Components:');
            for (var comp in components) {
              print(
                  '  - ${comp['type']}: ${comp['text'] ?? comp['format'] ?? ''}');
            }
          }
          print('-' * 60);
        }

        // Check for OTP templates
        final otpTemplates = templates
            .where((t) =>
                t['category'] == 'AUTHENTICATION' ||
                t['name'].toString().toLowerCase().contains('otp') ||
                t['name'].toString().toLowerCase().contains('verification'))
            .toList();

        if (otpTemplates.isNotEmpty) {
          print('\n*** OTP/Authentication Templates Found: ***');
          for (var t in otpTemplates) {
            print('  - ${t['name']} (${t['status']})');
          }
        } else {
          print('\n*** NO OTP Templates Found! ***');
          print('You need to create an OTP template.');
        }
      } else {
        print('\nNo templates found!');
        print('You need to create templates.');
      }
    } else {
      print('Error: ${data['error']?['message'] ?? response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }

  print('\n' + '=' * 60);
  print('To create a template, go to:');
  print(
      'https://business.facebook.com/wa/manage/message-templates/?waba_id=$wabaId');
  print('=' * 60);
}
