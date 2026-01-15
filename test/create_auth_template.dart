// Create Authentication OTP Template
// Authentication templates are pre-approved by Meta for OTP use cases
import 'package:http/http.dart' as http;
import 'dart:convert';

const String wabaId = '576625715530014';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('=' * 60);
  print('CREATING AUTHENTICATION OTP TEMPLATE');
  print('=' * 60);
  print('\nAuthentication templates are pre-approved by Meta!');
  print('This is the correct way to send OTP codes.\n');

  final url = '$baseUrl/$apiVersion/$wabaId/message_templates';

  // Authentication template format as per Meta's documentation
  // https://developers.facebook.com/docs/whatsapp/business-management-api/authentication-templates
  // For AUTHENTICATION category, the format is different - Meta auto-generates the body
  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'name': 'verification_code',
      'category': 'AUTHENTICATION',
      'language': 'en',
      'components': [
        {'type': 'BODY', 'add_security_recommendation': true},
        {'type': 'FOOTER', 'code_expiration_minutes': 5},
        {
          'type': 'BUTTONS',
          'buttons': [
            {'type': 'OTP', 'otp_type': 'COPY_CODE', 'text': 'Copy Code'}
          ]
        }
      ]
    }),
  );

  final data = json.decode(response.body);
  print('Status: ${response.statusCode}');
  print('Response: ${const JsonEncoder.withIndent('  ').convert(data)}');

  if (response.statusCode == 200 || response.statusCode == 201) {
    print('\n✅ SUCCESS! Template created!');
    print('Template ID: ${data['id']}');
    print('\n⚡ Authentication templates are usually auto-approved!');
    print('You can now send OTP messages to users.');
  } else {
    print('\n❌ FAILED to create template');
    print('Error: ${data['error']?['message']}');
    print('Details: ${data['error']?['error_user_msg']}');

    // Suggest alternatives
    print('\n' + '=' * 60);
    print('TROUBLESHOOTING:');
    print('=' * 60);

    final errorCode = data['error']?['code'];
    if (errorCode == 2388094) {
      print('⚠️ A template with this name already exists.');
      print(
          '   Try deleting the existing template first, or use a different name.');
    } else if (errorCode == 100) {
      print('⚠️ Invalid parameters. The template format may need adjustment.');
    } else if (errorCode == 190) {
      print('⚠️ Access token expired! Generate a new token from:');
      print('   https://developers.facebook.com/apps/');
    }

    print('\nAlternative: Create template manually at:');
    print(
        'https://business.facebook.com/wa/manage/message-templates/?waba_id=$wabaId');
  }
}
