// WhatsApp Message Send Test
// Test sending an actual message

import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

// Test phone number - CHANGE THIS TO YOUR NUMBER
const String testPhoneNumber = '972528180757'; // Without +

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('📤 WhatsApp Message Send Test');
  print('═══════════════════════════════════════════════════');
  print('');

  // Test 1: Send simple text message
  print('Test 1: Sending simple text message...');
  await sendTextMessage(
      testPhoneNumber, 'Test message from AQ CheatsTool API Test');

  print('');
  print('═══════════════════════════════════════════════════');
}

Future<void> sendTextMessage(String phone, String message) async {
  try {
    final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';

    print('URL: $url');
    print('To: $phone');
    print('Message: $message');
    print('');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'messaging_product': 'whatsapp',
        'recipient_type': 'individual',
        'to': phone,
        'type': 'text',
        'text': {
          'preview_url': false,
          'body': message,
        },
      }),
    );

    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');
    print('');

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ Message sent successfully!');
      final data = json.decode(response.body);
      print('Message ID: ${data['messages']?[0]?['id']}');
    } else {
      print('❌ Failed to send message');
      final error = json.decode(response.body);
      print('Error Code: ${error['error']?['code']}');
      print('Error Message: ${error['error']?['message']}');
      print('Error Details: ${error['error']?['error_data']?['details']}');

      // Common errors
      final errorCode = error['error']?['code'];
      if (errorCode == 131030) {
        print('');
        print('⚠️ RECIPIENT NOT IN WHITELIST');
        print('For sandbox/test mode, you must first:');
        print('1. Go to Meta Business Suite > WhatsApp > API Setup');
        print('2. Add test phone numbers to the whitelist');
        print(
            '3. The recipient must send a message to your business number first');
      } else if (errorCode == 131026) {
        print('');
        print('⚠️ MESSAGE TEMPLATE REQUIRED');
        print('For users who haven\'t messaged you in 24 hours,');
        print('you must use an approved message template.');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
