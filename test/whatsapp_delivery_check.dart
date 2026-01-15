// WhatsApp Delivery Check
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('🔍 WhatsApp Delivery Diagnostic');
  print('═══════════════════════════════════════════════════\n');

  // Check account info
  print('1️⃣ Business Phone Number Info:');
  await getPhoneInfo();

  print('\n2️⃣ Testing send to YOUR number (972528180757):');
  await testSendToNumber('972528180757');

  // Also check if there's a conversation history
  print('\n3️⃣ Checking recent messages...');
  await checkConversations();

  print('\n═══════════════════════════════════════════════════');
  print('🔧 TROUBLESHOOTING:');
  print('═══════════════════════════════════════════════════');
  print('');
  print('If you\'re not receiving messages, check:');
  print('');
  print('1. 📱 Is the phone number correct?');
  print('   - Business number: +972 52-486-4281');
  print('   - Your WhatsApp must be associated with this number');
  print('');
  print('2. 🔔 Check WhatsApp notifications:');
  print('   - Open WhatsApp');
  print('   - Search for "AQ///bimmer" in chats');
  print('   - Messages should appear there');
  print('');
  print('3. 📵 Check if blocked:');
  print('   - Make sure the business number is not blocked');
  print('');
  print('4. 🌐 Check internet connection');
  print('');
  print('═══════════════════════════════════════════════════');
}

Future<void> getPhoneInfo() async {
  final url =
      '$baseUrl/$apiVersion/$phoneNumberId?fields=display_phone_number,verified_name,quality_rating,account_mode';

  final response = await http.get(
    Uri.parse(url),
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    print('   📱 Business Number: ${data['display_phone_number']}');
    print('   ✅ Verified Name: ${data['verified_name']}');
    print('   📊 Quality: ${data['quality_rating']}');
    print('   🔧 Mode: ${data['account_mode'] ?? 'LIVE'}');
  }
}

Future<void> testSendToNumber(String phone) async {
  final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';

  final timestamp = DateTime.now().toString();

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
        'body':
            '🔔 Test Message\n\nThis is a test from AQ CheatsTool.\nTimestamp: $timestamp\n\nIf you receive this, WhatsApp API is working! ✅',
      },
    }),
  );

  print('   Sending to: $phone');
  print('   Status: ${response.statusCode}');

  final body = json.decode(response.body);

  if (response.statusCode == 200 || response.statusCode == 201) {
    print('   ✅ API Response: Message Accepted');
    print('   📧 Message ID: ${body['messages']?[0]?['id']}');
    print('   📱 Recipient WA ID: ${body['contacts']?[0]?['wa_id']}');
    print('');
    print('   ⚠️  Check your WhatsApp NOW!');
    print('   ⚠️  Look for chat from "+972 52-486-4281" or "AQ///bimmer"');
  } else {
    print('   ❌ Error: ${body['error']?['message']}');
    print('   Code: ${body['error']?['code']}');
  }
}

Future<void> checkConversations() async {
  // Check analytics
  final url =
      '$baseUrl/$apiVersion/$phoneNumberId?fields=analytics.start(2024-01-01).end(2026-01-31).granularity(DAY)';

  final response = await http.get(
    Uri.parse(url),
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    print('   📊 Analytics available - check Meta Business Suite for details');
  } else {
    print('   ℹ️ Cannot fetch analytics directly');
  }

  print('   💡 To see message status, set up Webhooks in Meta Business Suite');
}
