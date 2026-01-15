// Check WhatsApp Message Templates
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('📋 Checking WhatsApp Message Templates');
  print('═══════════════════════════════════════════════════\n');

  // First get WABA ID
  print('1️⃣ Getting WhatsApp Business Account ID...');
  final wabaId = await getWabaId();

  if (wabaId != null) {
    print('   ✅ WABA ID: $wabaId\n');

    print('2️⃣ Fetching message templates...');
    await getTemplates(wabaId);
  } else {
    print('   ❌ Could not get WABA ID\n');
    print('   Trying alternative method...');
    await getTemplatesAlternative();
  }

  print('\n═══════════════════════════════════════════════════');
  print('📝 HOW TO CREATE OTP TEMPLATE:');
  print('═══════════════════════════════════════════════════');
  print('');
  print('1. Go to: https://business.facebook.com/wa/manage/message-templates/');
  print('2. Click "Create Template"');
  print('3. Select Category: "AUTHENTICATION"');
  print('4. Template Name: "otp_verification"');
  print('5. Language: English (en)');
  print('6. Body: "Your verification code is: {{1}}"');
  print('7. Submit for approval (usually takes 1-2 hours)');
  print('');
  print('═══════════════════════════════════════════════════');
}

Future<String?> getWabaId() async {
  try {
    // Get phone number details which includes WABA reference
    final url =
        '$baseUrl/$apiVersion/$phoneNumberId?fields=id,display_phone_number,verified_name';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   Phone: ${data['display_phone_number']}');
      print('   Name: ${data['verified_name']}');

      // Try to get WABA ID from the account
      final wabaUrl = '$baseUrl/$apiVersion/me/accounts';
      final wabaResponse = await http.get(
        Uri.parse(wabaUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (wabaResponse.statusCode == 200) {
        final wabaData = json.decode(wabaResponse.body);
        print('   Accounts: ${wabaResponse.body}');
      }
    }
    return null;
  } catch (e) {
    print('   Error: $e');
    return null;
  }
}

Future<void> getTemplates(String wabaId) async {
  try {
    final url = '$baseUrl/$apiVersion/$wabaId/message_templates';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print('   Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final templates = data['data'] as List? ?? [];

      if (templates.isEmpty) {
        print('   ⚠️ No templates found');
      } else {
        print('   Found ${templates.length} templates:');
        for (var t in templates) {
          print('   - ${t['name']} (${t['status']})');
        }
      }
    } else {
      print('   Error: ${response.body}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}

Future<void> getTemplatesAlternative() async {
  try {
    // Try using debug_token to get app info
    final debugUrl =
        '$baseUrl/debug_token?input_token=$accessToken&access_token=$accessToken';

    final response = await http.get(Uri.parse(debugUrl));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   Token Info: ${json.encode(data['data'])}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}
