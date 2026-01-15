// WhatsApp Messaging Tier & Template Test
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('🔍 WhatsApp Messaging Analysis');
  print('═══════════════════════════════════════════════════\n');

  print('📊 Current Limits:');
  print('   TIER_250 = 250 unique users per 24 hours');
  print('   This is the STARTER tier for new business accounts\n');

  print('📋 To increase limits:');
  print('   1. Complete Business Verification');
  print('   2. Maintain good quality rating (currently GREEN ✅)');
  print('   3. Send more messages to increase tier automatically\n');

  print('═══════════════════════════════════════════════════');
  print('🔑 KEY FINDING: Interactive CTA messages may not work!');
  print('═══════════════════════════════════════════════════\n');

  print('Testing different message types...\n');

  // Test 1: Simple text message (should work)
  await testSimpleText('972528180757');

  // Test 2: Try authentication template
  await testAuthTemplate('972528180757');

  print('\n═══════════════════════════════════════════════════');
}

Future<void> testSimpleText(String phone) async {
  print('1️⃣ Testing SIMPLE TEXT message...');

  final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';

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
        'body': '🔐 Your verification code is: 12345\n\nValid for 5 minutes.',
      },
    }),
  );

  print('   Status: ${response.statusCode}');
  if (response.statusCode == 200 || response.statusCode == 201) {
    print('   ✅ Simple text works!\n');
  } else {
    final body = json.decode(response.body);
    print('   ❌ Error: ${body['error']?['message']}\n');
  }
}

Future<void> testAuthTemplate(String phone) async {
  print('2️⃣ Testing AUTHENTICATION template...');

  final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';

  // Try using the built-in authentication template
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
      'type': 'template',
      'template': {
        'name': 'hello_world', // Default template
        'language': {'code': 'en_US'},
      },
    }),
  );

  print('   Status: ${response.statusCode}');
  if (response.statusCode == 200 || response.statusCode == 201) {
    print('   ✅ Template works!\n');
  } else {
    final body = json.decode(response.body);
    print('   ❌ Error: ${body['error']?['message']}');
    print('   Details: ${body['error']?['error_data']?['details']}\n');
  }
}
