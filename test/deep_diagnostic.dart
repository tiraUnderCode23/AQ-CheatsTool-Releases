// Deep Diagnostic for WhatsApp Message Delivery
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String wabaId = '576625715530014';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('');
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║     🔬 Deep WhatsApp Diagnostic                               ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');

  final testPhone = '972528180757';

  // 1. Check conversations
  print('1️⃣ Checking recent conversations...');
  await checkConversations();
  print('');

  // 2. Try sending a simple text message (will fail if no 24h window)
  print('2️⃣ Testing 24-hour window with text message...');
  await testTextMessage(testPhone);
  print('');

  // 3. Check template details
  print('3️⃣ Checking aq_account_notification template details...');
  await checkTemplateDetails();
  print('');

  // 4. Try different approach - direct message
  print('4️⃣ Sending direct text message...');
  await sendDirectText(testPhone);
  print('');

  print('═══════════════════════════════════════════════════════════════');
  print('');
  print('📋 DIAGNOSIS:');
  print('');
  print('   API returns 200 (success) but message not delivered.');
  print('   This means:');
  print('');
  print('   ❌ The recipient has NOT opened a conversation with you');
  print('   ❌ OR the recipient blocked your number');
  print('   ❌ OR the number doesn\'t have WhatsApp');
  print('');
  print('   📱 MARKETING templates require user opt-in!');
  print('      Even approved templates won\'t deliver without prior consent.');
  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('');
  print('🔧 SOLUTIONS:');
  print('');
  print('   Option 1: Ask user to message first');
  print('   ────────────────────────────────────');
  print('   User must send any message to: +972 52-486-4281');
  print('');
  print('   Option 2: Create AUTHENTICATION template');
  print('   ────────────────────────────────────────');
  print('   AUTHENTICATION templates can reach users without prior contact.');
  print('   Go to: https://business.facebook.com/wa/manage/message-templates/');
  print('   Create template with category: AUTHENTICATION');
  print('');
  print('   Option 3: Use different messaging service for OTP');
  print('   ──────────────────────────────────────────────────');
  print('   Consider SMS as fallback for OTP delivery.');
  print('');
  print('═══════════════════════════════════════════════════════════════');
}

Future<void> checkConversations() async {
  try {
    // Get analytics/conversations
    final url =
        '$baseUrl/$apiVersion/$wabaId/conversation_analytics?start=1704067200&end=1737158400&granularity=DAILY';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   📊 Conversation analytics retrieved');

      final conversations = data['data'] as List? ?? [];
      if (conversations.isNotEmpty) {
        print('   Found conversation data');
      } else {
        print('   ⚠️ No recent conversations found');
      }
    } else {
      print('   ⚠️ Could not get conversation data');
    }
  } catch (e) {
    print('   Error: $e');
  }
}

Future<void> testTextMessage(String phone) async {
  try {
    final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'messaging_product': 'whatsapp',
        'to': phone,
        'type': 'text',
        'text': {'body': 'Test message - checking 24h window'}
      }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      print('   ✅ Text message accepted');
      print('   This means 24-hour window MAY be open');
      print('   Message ID: ${data['messages']?[0]?['id']}');
    } else {
      final error = data['error'];
      final errorCode = error?['code'];

      if (errorCode == 131047) {
        print('   ❌ 24-hour window is CLOSED');
        print('   User must message you first!');
      } else {
        print('   ❌ Error: ${error?['message']}');
      }
    }
  } catch (e) {
    print('   Error: $e');
  }
}

Future<void> checkTemplateDetails() async {
  try {
    final url =
        '$baseUrl/$apiVersion/$wabaId/message_templates?name=aq_account_notification';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final templates = data['data'] as List? ?? [];

      if (templates.isNotEmpty) {
        final t = templates[0];
        print('   📋 Template: ${t['name']}');
        print('   📊 Status: ${t['status']}');
        print('   📁 Category: ${t['category']}');
        print('   🌐 Language: ${t['language']}');
        print('   ⭐ Quality: ${t['quality_score']?['score'] ?? 'N/A'}');

        // Show components
        final components = t['components'] as List? ?? [];
        for (var c in components) {
          print('   📝 ${c['type']}: ${c['text'] ?? ''}');
        }

        // Check if MARKETING
        if (t['category'] == 'MARKETING') {
          print('');
          print('   ⚠️ MARKETING templates require user opt-in!');
          print('   ⚠️ User must have prior interaction with your business.');
        }
      }
    }
  } catch (e) {
    print('   Error: $e');
  }
}

Future<void> sendDirectText(String phone) async {
  try {
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
          'body': '🔐 Your AQ///bimmer verification code is: 12345'
        }
      }),
    );

    print('   Status: ${response.statusCode}');
    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      print('   ✅ Message accepted by API');
      print('   Message ID: ${data['messages']?[0]?['id']}');
      print('   ⚠️ But may not deliver if no 24h window');
    } else {
      final error = data['error'];
      print('   ❌ Error: ${error?['message']}');

      if (error?['code'] == 131047) {
        print('');
        print('   🚫 CONFIRMED: No 24-hour conversation window!');
        print('   User MUST send a message to +972 52-486-4281 first.');
      }
    }
  } catch (e) {
    print('   Error: $e');
  }
}
