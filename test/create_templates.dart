// Create proper OTP template
import 'package:http/http.dart' as http;
import 'dart:convert';

const String wabaId = '576625715530014';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('Creating proper templates...\n');

  // Template 1: Simple welcome/notification template
  print('1. Creating welcome template...');
  await createTemplate({
    'name': 'aq_welcome_message',
    'category': 'UTILITY',
    'language': 'en',
    'components': [
      {
        'type': 'BODY',
        'text':
            'Welcome to AQ///bimmer Tools! Your account has been activated successfully.'
      }
    ]
  });

  // Template 2: Account notification
  print('\n2. Creating account notification template...');
  await createTemplate({
    'name': 'aq_account_notification',
    'category': 'UTILITY',
    'language': 'en',
    'components': [
      {
        'type': 'BODY',
        'text':
            'Hello {{1}}, this is a notification from AQ///bimmer Tools regarding your account.',
        'example': {
          'body_text': [
            ['John']
          ]
        }
      }
    ]
  });

  // Template 3: Activation key
  print('\n3. Creating activation key template...');
  await createTemplate({
    'name': 'aq_activation_key',
    'category': 'UTILITY',
    'language': 'en',
    'components': [
      {
        'type': 'BODY',
        'text':
            'Your activation key for AQ///bimmer Tools is: {{1}}. This key is valid for your registered device.',
        'example': {
          'body_text': [
            ['XXXX-XXXX-XXXX']
          ]
        }
      }
    ]
  });

  // Check all templates
  print('\n' + '=' * 50);
  print('Checking all templates...');
  final url = '$baseUrl/$apiVersion/$wabaId/message_templates';
  final response = await http.get(
    Uri.parse(url),
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  final data = json.decode(response.body);
  if (response.statusCode == 200) {
    final templates = data['data'] as List?;
    if (templates != null) {
      print('\nAll templates (${templates.length}):');
      for (var t in templates) {
        final status = t['status'];
        final icon =
            status == 'APPROVED' ? '✅' : (status == 'PENDING' ? '⏳' : '❌');
        print('  $icon ${t['name']} - $status');
      }
    }
  }
}

Future<void> createTemplate(Map<String, dynamic> template) async {
  final url = '$baseUrl/$apiVersion/$wabaId/message_templates';

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(template),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('   ✅ Created: ${template['name']} (ID: ${data['id']})');
    } else {
      print('   ❌ Failed: ${data['error']?['message']}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}
