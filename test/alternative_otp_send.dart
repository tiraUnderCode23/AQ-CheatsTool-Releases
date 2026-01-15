// Alternative: Send OTP via Interactive Message or Session Message
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

const String testPhone = '972528180757';
const String testOtp = '12345';

Future<void> main() async {
  print('');
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║     📤 Alternative OTP Sending Methods                        ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');

  // Method 1: Interactive message with button
  print('1️⃣ Sending Interactive Message with Copy Button...');
  await sendInteractiveMessage(testPhone, testOtp);
  print('');

  // Method 2: Check if we can send regular text (24h window)
  print('2️⃣ Sending Regular Text Message...');
  await sendTextMessage(testPhone, testOtp);
  print('');

  // Method 3: Try with reaction/context
  print('3️⃣ Sending Text with Preview...');
  await sendTextWithPreview(testPhone, testOtp);
  print('');

  print('═══════════════════════════════════════════════════════════════');
  print('');
  print('📋 NOTE: If none of these work, the user MUST:');
  print('   1. Send any message to +972 52-486-4281 first');
  print('   2. Or you need an AUTHENTICATION template (manual creation)');
  print('');
  print('═══════════════════════════════════════════════════════════════');
}

Future<void> sendInteractiveMessage(String phone, String otp) async {
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
        'type': 'interactive',
        'interactive': {
          'type': 'button',
          'body': {
            'text':
                '🔐 Your AQ///bimmer verification code is:\n\n*$otp*\n\nThis code expires in 5 minutes.'
          },
          'action': {
            'buttons': [
              {
                'type': 'reply',
                'reply': {'id': 'copy_code', 'title': '📋 Copy: $otp'}
              }
            ]
          }
        }
      }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      print('   ✅ Interactive message sent!');
      print('   Message ID: ${data['messages']?[0]?['id']}');
    } else {
      print('   ❌ Failed: ${data['error']?['message']}');
      final errorCode = data['error']?['code'];
      if (errorCode == 131047) {
        print('   ⚠️ 24-hour window not open - user must message first');
      }
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}

Future<void> sendTextMessage(String phone, String otp) async {
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
          'body': '''🔐 *AQ///bimmer Verification*

Your code is: *$otp*

⏱️ Expires in 5 minutes
⚠️ Do not share this code'''
        }
      }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      print('   ✅ Text message sent!');
      print('   Message ID: ${data['messages']?[0]?['id']}');
    } else {
      print('   ❌ Failed: ${data['error']?['message']}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}

Future<void> sendTextWithPreview(String phone, String otp) async {
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
        'text': {
          'preview_url': true,
          'body':
              '🔐 Your AQ///bimmer code: *$otp* - Valid 5 min. https://aqbimmer.com'
        }
      }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      print('   ✅ Text with preview sent!');
      print('   Message ID: ${data['messages']?[0]?['id']}');
    } else {
      print('   ❌ Failed: ${data['error']?['message']}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}
