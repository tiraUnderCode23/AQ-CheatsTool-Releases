// Test sending OTP using approved templates
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

// Approved templates
const List<String> approvedTemplates = [
  'aq_account_notification', // Has {{1}} parameter
  'wba',
  'aq_welcome_message',
];

Future<void> main() async {
  print('');
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║     📤 Test OTP Sending with Approved Templates               ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');

  // Test phone number (use your own number for testing)
  const testPhone = '972528180757'; // Change to test number
  const testOtp = '12345';

  print('📱 Test Phone: +$testPhone');
  print('🔐 Test OTP: $testOtp');
  print('');

  for (final templateName in approvedTemplates) {
    print('─────────────────────────────────────────────────');
    print('Testing template: $templateName');
    print('─────────────────────────────────────────────────');

    final success = await sendOtpWithTemplate(
      phone: testPhone,
      otp: testOtp,
      templateName: templateName,
    );

    if (success) {
      print('');
      print('✅ SUCCESS! Use this template in your app:');
      print('   Template Name: $templateName');
      break;
    }
    print('');
  }
}

Future<bool> sendOtpWithTemplate({
  required String phone,
  required String otp,
  required String templateName,
}) async {
  final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';

  try {
    // Build request body based on template
    Map<String, dynamic> requestBody;

    if (templateName == 'aq_account_notification') {
      // This template has format: "Hello {{1}}, this is a notification..."
      // NOTE: Parameters cannot contain newlines, tabs, or 4+ consecutive spaces
      requestBody = {
        'messaging_product': 'whatsapp',
        'recipient_type': 'individual',
        'to': phone,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {'code': 'en'},
          'components': [
            {
              'type': 'body',
              'parameters': [
                {
                  'type': 'text',
                  'text': '🔐 Your OTP code is: $otp (expires in 5 min)'
                }
              ]
            }
          ]
        }
      };
    } else if (templateName == 'wba') {
      // wba template - may not have parameters
      requestBody = {
        'messaging_product': 'whatsapp',
        'recipient_type': 'individual',
        'to': phone,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {'code': 'en'},
        }
      };
    } else {
      // Generic template with single parameter
      requestBody = {
        'messaging_product': 'whatsapp',
        'recipient_type': 'individual',
        'to': phone,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {'code': 'en'},
          'components': [
            {
              'type': 'body',
              'parameters': [
                {'type': 'text', 'text': otp}
              ]
            }
          ]
        }
      };
    }

    print('   Sending request...');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );

    print('   Status: ${response.statusCode}');

    final data = json.decode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final messageId = data['messages']?[0]?['id'];
      print('   ✅ Message sent successfully!');
      print('   Message ID: $messageId');
      return true;
    } else {
      final error = data['error'];
      print('   ❌ Failed: ${error?['message']}');
      if (error?['error_data']?['details'] != null) {
        print('   Details: ${error['error_data']['details']}');
      }
      return false;
    }
  } catch (e) {
    print('   ❌ Exception: $e');
    return false;
  }
}
