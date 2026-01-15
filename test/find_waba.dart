// Find WABA ID
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('🔍 Finding WhatsApp Business Account ID');
  print('═══════════════════════════════════════════════════\n');

  // Method 1: Get from phone number
  print('Method 1: From phone number...');
  final url1 =
      '$baseUrl/$apiVersion/$phoneNumberId?fields=id,display_phone_number,verified_name,name_status,new_name_status,quality_rating,code_verification_status';
  await makeRequest(url1);

  // Method 2: Try different endpoints
  print('\nMethod 2: Business info...');
  final url2 =
      '$baseUrl/$apiVersion/122105239143201499?fields=id,name,businesses';
  await makeRequest(url2);

  // Method 3: Get all businesses
  print('\nMethod 3: All businesses...');
  final url3 = '$baseUrl/$apiVersion/me/businesses';
  await makeRequest(url3);

  // Method 4: Get owned WABAs
  print('\nMethod 4: Owned WABAs (from business manager)...');
  final url4 =
      '$baseUrl/$apiVersion/569217266268972/owned_whatsapp_business_accounts';
  await makeRequest(url4);

  print('\n═══════════════════════════════════════════════════');
  print('💡 SOLUTION:');
  print('═══════════════════════════════════════════════════');
  print('');
  print('To find your WABA ID and create templates:');
  print('');
  print('1. Go to: https://business.facebook.com/settings/');
  print('2. Click on "Accounts" > "WhatsApp Accounts"');
  print('3. Select your WhatsApp Business Account');
  print('4. The WABA ID is in the URL after /whatsapp/');
  print('');
  print('Or go directly to:');
  print('https://business.facebook.com/wa/manage/message-templates/');
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
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   ✅ ${const JsonEncoder.withIndent('  ').convert(data)}');
    } else {
      final error = json.decode(response.body);
      print('   ❌ ${error['error']?['message'] ?? response.body}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}
