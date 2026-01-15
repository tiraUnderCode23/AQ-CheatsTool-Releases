// Final test - Send message and check delivery
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('=' * 60);
  print('FINAL WHATSAPP MESSAGE TEST');
  print('=' * 60);

  final targetPhone = '972528180757';
  final otp = '12345';

  print('\nTarget: +$targetPhone');
  print('OTP: $otp');
  print('Time: ${DateTime.now()}\n');

  // Send OTP message
  print('Sending OTP message...');
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
      'to': targetPhone,
      'type': 'text',
      'text': {
        'preview_url': false,
        'body': '''AQ///bimmer Tools

Your verification code is: $otp

This code expires in 5 minutes.
Do not share this code with anyone.'''
      }
    }),
  );

  final data = json.decode(response.body);
  print('\nResponse Status: ${response.statusCode}');
  print('Response: ${const JsonEncoder.withIndent('  ').convert(data)}');

  if (response.statusCode == 200) {
    final messageId = data['messages']?[0]?['id'];
    final messageStatus = data['messages']?[0]?['message_status'];

    print('\n' + '=' * 60);
    print('MESSAGE SENT SUCCESSFULLY!');
    print('=' * 60);
    print('Message ID: $messageId');
    print('Initial Status: $messageStatus');
    print('\nPossible reasons if not delivered:');
    print('1. User has not messaged this business number before (24h window)');
    print('2. User phone number is incorrect');
    print('3. WhatsApp is not installed on the phone');
    print('4. User has blocked the business number');
    print('\nBusiness Number: +972 52-486-4281');
    print('User should message this number first to open 24h window.');
  } else {
    print('\n' + '=' * 60);
    print('MESSAGE FAILED!');
    print('=' * 60);
    print('Error: ${data['error']?['message']}');
    print('Code: ${data['error']?['code']}');
  }
}
