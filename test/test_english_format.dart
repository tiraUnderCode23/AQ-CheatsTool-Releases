// Test English only format
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('=' * 60);
  print('TESTING ENGLISH ONLY FORMAT');
  print('=' * 60);

  final targetPhone = '972528180757';
  final userName = 'Ahmad';
  final activationKey = 'NVB6M-6QXD2UE7-TAFG3';

  // New format - English only with beautiful formatting
  final message = '''🔄 *AQ CheatsTool - Activation Key Renewal*

Hello *$userName*,

Your activation key has been successfully renewed! 🎉

New Activation Key:
*$activationKey*

📱 You can now use this key to activate the program on your device.

⚠️ Important Notes:
• Activation key is linked to one device only
• Old key has been cancelled
• Do not share this key with anyone

Thank you for choosing AQ///BIMMER! 🚗

_AQ///BIMMER Team_''';

  print('\nSending message to: +$targetPhone');
  print('Format: English Only\n');

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
      'text': {'preview_url': false, 'body': message}
    }),
  );

  final data = json.decode(response.body);
  print('Status: ${response.statusCode}');

  if (response.statusCode == 200) {
    print('✅ Message sent successfully!');
    print('Message ID: ${data['messages']?[0]?['id']}');
    print('\n📱 Check your phone!');
  } else {
    print('❌ Failed to send message');
    print('Error: ${data['error']?['message']}');
  }
}
