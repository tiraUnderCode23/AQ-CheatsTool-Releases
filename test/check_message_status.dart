// Check WhatsApp Message Delivery Status
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String wabaId = '576625715530014';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

// Last sent message IDs
const List<String> messageIds = [
  'wamid.HBgMOTcyNTI4MTgwNzU3FQIAERgSNEQ3MDVCMzZFNjYxRUJBMjNFAA==',
  'wamid.HBgMOTcyNTI4MTgwNzU3FQIAERgSRjUzRjFCRjY5NEE5Rjg3RDNBAA==',
];

Future<void> main() async {
  print('');
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║     🔍 WhatsApp Message Delivery Diagnostic                   ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');

  // 1. Check phone number status
  print('1️⃣ Checking Business Phone Number Status...');
  await checkPhoneStatus();
  print('');

  // 2. Check messaging limits
  print('2️⃣ Checking Messaging Limits & Quality...');
  await checkMessagingLimits();
  print('');

  // 3. Check if recipient is valid
  print('3️⃣ Checking Recipient Number...');
  await checkRecipient('972528180757');
  print('');

  // 4. Try to get message status
  print('4️⃣ Message IDs sent:');
  for (var id in messageIds) {
    print('   📨 $id');
  }
  print('');

  // 5. Show important notes
  print('═══════════════════════════════════════════════════════════════');
  print('');
  print('📋 COMMON REASONS WHY MESSAGES ARE NOT DELIVERED:');
  print('');
  print('   1️⃣ 24-HOUR WINDOW NOT OPEN');
  print('      The recipient must first send a message to your business');
  print('      number (+972 52-486-4281) to open a conversation window.');
  print('');
  print('   2️⃣ TEMPLATE MESSAGES ONLY');
  print('      For users who haven\'t messaged you, ONLY approved template');
  print('      messages can be sent. Regular text messages will NOT work.');
  print('');
  print('   3️⃣ USER BLOCKED YOUR NUMBER');
  print('      The user may have blocked your business number.');
  print('');
  print('   4️⃣ INVALID PHONE NUMBER');
  print('      The number may not have WhatsApp installed.');
  print('');
  print('   5️⃣ ACCOUNT QUALITY ISSUES');
  print('      Your business account may have quality restrictions.');
  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('');
  print('🔧 SOLUTION:');
  print('');
  print('   Ask the user to send any message (like "Hi") to:');
  print('   📱 +972 52-486-4281 (AQ///bimmer)');
  print('');
  print('   Then you can send messages to them for 24 hours.');
  print('');
  print('═══════════════════════════════════════════════════════════════');

  // 6. Test with a simple template without parameters
  print('');
  print('5️⃣ Testing with hello_world template (Meta default)...');
  await testHelloWorld('972528180757');
}

Future<void> checkPhoneStatus() async {
  try {
    final url =
        '$baseUrl/$apiVersion/$phoneNumberId?fields=id,display_phone_number,verified_name,quality_rating,messaging_limit_tier,is_official_business_account,account_mode,status';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   📱 Phone: ${data['display_phone_number']}');
      print('   📛 Name: ${data['verified_name']}');
      print('   ⭐ Quality: ${data['quality_rating'] ?? 'N/A'}');
      print('   📊 Tier: ${data['messaging_limit_tier'] ?? 'N/A'}');
      print('   🏢 Official: ${data['is_official_business_account'] ?? 'N/A'}');
      print('   📍 Status: ${data['status'] ?? 'N/A'}');
      print('   🔧 Mode: ${data['account_mode'] ?? 'N/A'}');
    } else {
      print('   ❌ Error: ${response.body}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}

Future<void> checkMessagingLimits() async {
  try {
    // Check WABA quality
    final url =
        '$baseUrl/$apiVersion/$wabaId?fields=id,name,message_template_namespace,account_review_status';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   🏢 WABA: ${data['name']}');
      print('   📋 Namespace: ${data['message_template_namespace'] ?? 'N/A'}');
      print('   ✅ Review Status: ${data['account_review_status'] ?? 'N/A'}');
    } else {
      print('   ⚠️ Could not fetch WABA info');
    }
  } catch (e) {
    print('   Error: $e');
  }
}

Future<void> checkRecipient(String phone) async {
  print('   📱 Recipient: +$phone');
  print('   ⚠️ Cannot verify if user has WhatsApp (API limitation)');
  print('   ⚠️ Cannot verify if user blocked you (API limitation)');
  print('   ℹ️ Messages show as "sent" even if not delivered');
}

Future<void> testHelloWorld(String phone) async {
  try {
    final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';

    // Try the default hello_world template that every account has
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'messaging_product': 'whatsapp',
        'to': phone,
        'type': 'template',
        'template': {
          'name': 'hello_world',
          'language': {'code': 'en_US'},
        }
      }),
    );

    print('   Status: ${response.statusCode}');
    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      print('   ✅ hello_world template sent');
      print('   Message ID: ${data['messages']?[0]?['id']}');
      print('');
      print('   ⚠️ If this also doesn\'t arrive, the issue is:');
      print('      - User hasn\'t messaged your business first, OR');
      print('      - User blocked your number, OR');
      print('      - Number doesn\'t have WhatsApp');
    } else {
      final error = data['error'];
      print('   ❌ Failed: ${error?['message']}');
      if (error?['error_data']?['details'] != null) {
        print('   Details: ${error['error_data']['details']}');
      }
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}
