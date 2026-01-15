// WhatsApp API Test Script
// Run this to verify the API token status

import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('🔍 WhatsApp Business API Token Verification');
  print('═══════════════════════════════════════════════════');
  print('');
  print('Phone Number ID: $phoneNumberId');
  print('API Version: $apiVersion');
  print('');

  try {
    // Test 1: Verify token by getting phone number info
    print('📡 Testing API connection...');
    final url = '$baseUrl/$apiVersion/$phoneNumberId';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    print('Response Status: ${response.statusCode}');
    print('');

    if (response.statusCode == 200) {
      print('✅ TOKEN IS VALID!');
      final data = json.decode(response.body);
      print('Phone Info: ${json.encode(data)}');
    } else {
      print('❌ TOKEN IS INVALID!');
      final error = json.decode(response.body);
      print('Error Code: ${error['error']?['code']}');
      print('Error Type: ${error['error']?['type']}');
      print('Error Message: ${error['error']?['message']}');
      print('');

      if (error['error']?['code'] == 190) {
        print('⚠️ ACCESS TOKEN HAS EXPIRED!');
        print('');
        print('To fix this issue:');
        print('1. Go to https://developers.facebook.com/apps/');
        print('2. Select your WhatsApp Business app');
        print('3. Go to WhatsApp > API Setup');
        print('4. Generate a new temporary access token');
        print('   OR create a System User token for permanent access');
        print('');
        print('For permanent token:');
        print('1. Go to Business Settings > System Users');
        print('2. Create a new System User');
        print('3. Assign WhatsApp Business Account');
        print('4. Generate a permanent token');
      }
    }
  } catch (e) {
    print('❌ Connection Error: $e');
  }

  print('');
  print('═══════════════════════════════════════════════════');
}
