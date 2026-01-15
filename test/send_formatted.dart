// Send formatted text message (no CTA)
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('=' * 60);
  print('SENDING FORMATTED TEXT MESSAGE (NO CTA)');
  print('=' * 60);

  final targetPhone = '972528180757';
  final otp = '98765';

  print('\nTarget: +$targetPhone');
  print('OTP: $otp');
  print('Time: ${DateTime.now()}\n');

  final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';

  // Formatted text message - simple and clean
  final message = '''🔐 *AQ///bimmer Tools*

━━━━━━━━━━━━━━━━━━━━
   رمز التحقق الخاص بك
━━━━━━━━━━━━━━━━━━━━

        *$otp*

━━━━━━━━━━━━━━━━━━━━

⏱️ صالح لمدة 10 دقائق
⚠️ لا تشارك هذا الرمز مع أي شخص''';

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': targetPhone,
      'type': 'text',
      'text': {'preview_url': false, 'body': message}
    }),
  );

  final data = json.decode(response.body);
  print('Status: ${response.statusCode}');
  print('Response: ${const JsonEncoder.withIndent('  ').convert(data)}');

  if (response.statusCode == 200) {
    print('\n✅ Message sent successfully!');
    print('Message ID: ${data['messages']?[0]?['id']}');
  } else {
    print('\n❌ Failed to send message');
    print('Error: ${data['error']?['message']}');
  }
}
