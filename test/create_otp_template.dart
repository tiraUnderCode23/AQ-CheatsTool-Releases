// Create OTP Message Template
import 'package:http/http.dart' as http;
import 'dart:convert';

const String wabaId = '576625715530014'; // AQ///bimmer WABA
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('Creating OTP Message Template...\n');
  print('=' * 60);

  final url = '$baseUrl/$apiVersion/$wabaId/message_templates';

  // Create OTP authentication template
  final templateData = {
    'name': 'aq_otp_verification',
    'category': 'AUTHENTICATION',
    'allow_category_change': true,
    'language': 'en',
    'components': [
      {
        'type': 'BODY',
        'text':
            'Your verification code is {{1}}. This code expires in 10 minutes.',
        'example': {
          'body_text': [
            ['123456']
          ]
        }
      },
      {'type': 'FOOTER', 'text': 'AQ///bimmer Tools'}
    ]
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(templateData),
    );

    print('Status: ${response.statusCode}');
    final data = json.decode(response.body);
    print('Response: ${const JsonEncoder.withIndent('  ').convert(data)}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('\n SUCCESS! Template created.');
      print('Template ID: ${data['id']}');
      print('Status: The template will be reviewed by Meta.');
      print('This usually takes a few minutes to a few hours.');
    } else {
      print('\n ERROR creating template.');

      // Try alternative OTP template format
      print('\nTrying alternative format...');
      await createAlternativeTemplate(url);
    }
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> createAlternativeTemplate(String url) async {
  // Try with OTP button
  final templateData = {
    'name': 'aq_verification_code',
    'category': 'AUTHENTICATION',
    'language': 'en',
    'components': [
      {
        'type': 'BODY',
        'add_security_recommendation': true,
      },
      {
        'type': 'FOOTER',
        'code_expiration_minutes': 10,
      },
      {
        'type': 'BUTTONS',
        'buttons': [
          {'type': 'OTP', 'otp_type': 'COPY_CODE', 'text': 'Copy code'}
        ]
      }
    ]
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(templateData),
    );

    print('Status: ${response.statusCode}');
    final data = json.decode(response.body);
    print('Response: ${const JsonEncoder.withIndent('  ').convert(data)}');
  } catch (e) {
    print('Error: $e');
  }
}
