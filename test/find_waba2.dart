// Get WABA ID via different method
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('🔍 Finding WABA ID via granular scopes');
  print('═══════════════════════════════════════════════════\n');

  // Method: Get debug token info
  print('1. Debug token info...');
  final debugUrl =
      '$baseUrl/debug_token?input_token=$accessToken&access_token=$accessToken';
  await makeRequest(debugUrl);

  // Try to get businesses owned by the app
  print('\n2. App owned businesses...');
  final appId = 'EAAeA3FDAMxk'; // First part of token is app ID
  final url2 = '$baseUrl/$apiVersion/me/accounts';
  await makeRequest(url2);

  // Try direct WABA access (common WABA IDs pattern)
  print('\n3. Trying common WABA endpoints...');

  // WhatsApp business management API
  final url3 = '$baseUrl/$apiVersion/me?fields=id,name';
  await makeRequest(url3);

  // Try to get templates directly with phone number ID
  // Sometimes WABA ID == Phone Number ID for certain accounts
  print('\n4. Trying templates with phone number ID...');
  final url4 = '$baseUrl/$apiVersion/$phoneNumberId/message_templates';
  await makeRequest(url4);

  // Get App info
  print('\n5. App info...');
  final url5 = '$baseUrl/$apiVersion/app';
  await makeRequest(url5);

  print('\n═══════════════════════════════════════════════════');
  print('💡 SOLUTION:');
  print('═══════════════════════════════════════════════════');
  print('');
  print('بما أن الـ Token لديه صلاحيات محدودة،');
  print('يجب عليك:');
  print('');
  print('1. افتح هذا الرابط في المتصفح:');
  print('   https://business.facebook.com/latest/inbox/settings/');
  print('');
  print('2. أو اذهب إلى WhatsApp Manager:');
  print('   https://business.facebook.com/wa/manage/');
  print('');
  print('3. أو افتح Meta Business Suite:');
  print('   https://business.facebook.com/');
  print('   ثم اذهب الى: اعدادات - واتساب');
  print('');
  print('═══════════════════════════════════════════════════');
}

Future<void> makeRequest(String url) async {
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print('   Status: ${response.statusCode}');
    final data = json.decode(response.body);
    if (response.statusCode == 200) {
      print('   ✅ ${const JsonEncoder.withIndent('      ').convert(data)}');
    } else {
      print('   ❌ ${data['error']?['message'] ?? response.body}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}
