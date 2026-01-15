// Test OTP Sending - Simulates the app's OTP sending logic
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

// Test phone number - change this to your test number
const String testPhone = '972528180757';
const String testOtp = '12345';

// Template names to try
const List<String> templateNames = [
  'verification_code',
  'aq_otp_code',
  'aq_activation_key',
];

Future<void> main() async {
  print('=' * 60);
  print('TESTING OTP SENDING');
  print('=' * 60);
  print('\nTest Phone: $testPhone');
  print('Test OTP: $testOtp\n');

  // 1. First verify token
  print('1️⃣ Verifying API Token...');
  final tokenValid = await verifyToken();

  if (!tokenValid) {
    print('\n❌ Token is invalid. Please generate a new token.');
    print('Go to: https://developers.facebook.com/apps/');
    return;
  }

  print('\n2️⃣ Trying to send OTP via templates...');

  // 2. Try each template
  for (final templateName in templateNames) {
    print('\n   Trying template: $templateName');
    final success = await sendWithTemplate(templateName, testOtp);

    if (success) {
      print('\n✅ SUCCESS! OTP sent via template: $templateName');
      return;
    }
  }

  // 3. If all templates fail, try text message (only works within 24hr window)
  print('\n3️⃣ All templates failed. Trying text message fallback...');
  final textSuccess = await sendTextMessage(testOtp);

  if (textSuccess) {
    print('\n✅ SUCCESS! OTP sent via text message');
    print(
        '⚠️ Note: Text messages only work if user messaged you in last 24 hours');
  } else {
    print('\n❌ FAILED! Could not send OTP');
    print('\n' + '=' * 60);
    print('TO FIX THIS:');
    print('=' * 60);
    print('''
1. Create an approved OTP template in Meta Business Suite:
   https://business.facebook.com/wa/manage/message-templates/

2. Choose Category: AUTHENTICATION (auto-approved for OTP)
   Or Category: UTILITY (needs manual approval)

3. Template Name: verification_code
   Body: Your verification code is {{1}}.

4. Wait for approval (AUTHENTICATION templates are usually instant)
''');
  }
}

Future<bool> verifyToken() async {
  try {
    final url = '$baseUrl/$apiVersion/$phoneNumberId';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      print('   ✅ Token is VALID');
      return true;
    } else {
      final data = json.decode(response.body);
      print('   ❌ Token is INVALID: ${data['error']?['message']}');
      return false;
    }
  } catch (e) {
    print('   ❌ Error: $e');
    return false;
  }
}

Future<bool> sendWithTemplate(String templateName, String otp) async {
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
        'to': testPhone,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {'code': 'en'},
          'components': [
            {
              'type': 'body',
              'parameters': [
                {'type': 'text', 'text': otp}
              ]
            }
          ]
        }
      }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      print('   ✅ Sent! Message ID: ${data['messages']?[0]?['id']}');
      return true;
    } else {
      final errorCode = data['error']?['code'];
      final errorMsg = data['error']?['message'];
      print('   ❌ Failed ($errorCode): $errorMsg');

      if (errorCode == 132001) {
        print('   ⚠️ Template not found or not approved');
      }
      return false;
    }
  } catch (e) {
    print('   ❌ Error: $e');
    return false;
  }
}

Future<bool> sendTextMessage(String otp) async {
  try {
    final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';
    final message = '''🔐 *AQ CheatsTool - OTP Verification*

Your verification code is:

*$otp*

⏰ Valid for 5 minutes only.
⚠️ Do not share this code with anyone.

_AQ///BIMMER Team_''';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'messaging_product': 'whatsapp',
        'to': testPhone,
        'type': 'text',
        'text': {'body': message}
      }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200) {
      print('   ✅ Sent! Message ID: ${data['messages']?[0]?['id']}');
      return true;
    } else {
      final errorCode = data['error']?['code'];
      final errorMsg = data['error']?['message'];
      print('   ❌ Failed ($errorCode): $errorMsg');
      return false;
    }
  } catch (e) {
    print('   ❌ Error: $e');
    return false;
  }
}
