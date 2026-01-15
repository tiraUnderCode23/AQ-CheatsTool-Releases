// WhatsApp Full Debug Test
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('🔍 WhatsApp Business API Full Debug');
  print('═══════════════════════════════════════════════════\n');

  // 1. Check phone number status
  print('1️⃣ Checking Phone Number Status...');
  await checkPhoneStatus();

  print('\n2️⃣ Checking Business Account...');
  await checkBusinessAccount();

  print('\n3️⃣ Testing Message to different number...');
  // Test with a different format
  await testMessageFormats();

  print('\n═══════════════════════════════════════════════════');
}

Future<void> checkPhoneStatus() async {
  try {
    final url =
        '$baseUrl/$apiVersion/$phoneNumberId?fields=id,display_phone_number,verified_name,quality_rating,messaging_limit_tier,is_official_business_account,account_mode';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   ✅ Phone ID: ${data['id']}');
      print('   📱 Number: ${data['display_phone_number']}');
      print('   ✔️ Verified Name: ${data['verified_name']}');
      print('   📊 Quality: ${data['quality_rating']}');
      print(
          '   📨 Messaging Limit: ${data['messaging_limit_tier'] ?? 'Not set'}');
      print(
          '   🏢 Official Account: ${data['is_official_business_account'] ?? false}');
      print('   🔧 Account Mode: ${data['account_mode'] ?? 'LIVE'}');
    } else {
      print('   ❌ Error: ${response.body}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}

Future<void> checkBusinessAccount() async {
  try {
    // Get WABA ID from phone number
    final url =
        '$baseUrl/$apiVersion/$phoneNumberId?fields=whatsapp_business_account';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final waba = data['whatsapp_business_account'];
      if (waba != null) {
        print('   ✅ WABA ID: ${waba['id']}');

        // Get WABA details
        final wabaUrl =
            '$baseUrl/$apiVersion/${waba['id']}?fields=name,currency,timezone_id,message_template_namespace';
        final wabaResponse = await http.get(
          Uri.parse(wabaUrl),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        if (wabaResponse.statusCode == 200) {
          final wabaData = json.decode(wabaResponse.body);
          print('   📛 Name: ${wabaData['name']}');
          print('   💰 Currency: ${wabaData['currency']}');
          print('   🌍 Timezone: ${wabaData['timezone_id']}');
          print(
              '   📋 Template Namespace: ${wabaData['message_template_namespace']}');
        }
      }
    } else {
      print('   ❌ Error: ${response.body}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}

Future<void> testMessageFormats() async {
  // Test sending to the business number itself (should work)
  final testNumber =
      '972524864281'; // The business number from display_phone_number

  print('   Testing message to: $testNumber');

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
      'to': testNumber,
      'type': 'text',
      'text': {
        'preview_url': false,
        'body': 'Debug test message - ${DateTime.now()}',
      },
    }),
  );

  print('   Status: ${response.statusCode}');

  final body = json.decode(response.body);
  if (response.statusCode == 200 || response.statusCode == 201) {
    print('   ✅ API accepted message');
    print('   Message ID: ${body['messages']?[0]?['id']}');
    print('   Contact WA ID: ${body['contacts']?[0]?['wa_id']}');

    // Check message status
    final messageId = body['messages']?[0]?['id'];
    if (messageId != null) {
      print('\n   📊 Checking message status...');
      print(
          '   Note: Message status webhooks are needed for delivery confirmation');
    }
  } else {
    print('   ❌ Error Code: ${body['error']?['code']}');
    print('   ❌ Error Type: ${body['error']?['type']}');
    print('   ❌ Error Message: ${body['error']?['message']}');
    print('   ❌ Error Details: ${body['error']?['error_data']?['details']}');
  }
}
