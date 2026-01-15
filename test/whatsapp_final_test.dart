// WhatsApp Final Test - Simulate User Registration
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('📤 WhatsApp OTP Simulation Test');
  print('═══════════════════════════════════════════════════\n');

  // Simulate sending OTP like the app does
  final testPhone = '972528180757'; // Change to test number
  final otp = '12345';
  final userName = 'Test User';

  print('Simulating OTP send to: $testPhone');
  print('OTP: $otp');
  print('User: $userName\n');

  final message = '''🔐 *AQ CheatsTool - OTP Verification*

Hello *$userName*,

Your verification code is:

*$otp*

⏰ Valid for 5 minutes only.
⚠️ Do not share this code with anyone.

_AQ///BIMMER Team_
🌐 https://aqbimmer.com''';

  await sendMessage(testPhone, message);

  print('\n═══════════════════════════════════════════════════');
  print('📋 IMPORTANT NOTES:');
  print('═══════════════════════════════════════════════════');
  print('');
  print('If messages are NOT being delivered to users:');
  print('');
  print('1. ⏰ 24-HOUR WINDOW ISSUE:');
  print('   - Users must first message YOUR business number');
  print('   - Then you can reply within 24 hours');
  print('   - Solution: Ask user to send "Hi" to +972 52-486-4281 first');
  print('');
  print('2. 📋 USE MESSAGE TEMPLATES:');
  print('   - Create an approved template in Meta Business Suite');
  print('   - Go to: business.facebook.com/wa/manage/message-templates/');
  print('   - Create AUTHENTICATION template for OTP');
  print('');
  print('3. 📱 PHONE NUMBER FORMAT:');
  print('   - Must be international format without +');
  print('   - Example: 972528180757 (not +972-528-180-757)');
  print('');
  print('═══════════════════════════════════════════════════');
}

Future<void> sendMessage(String phone, String message) async {
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
        'body': message,
      },
    }),
  );

  print('Response Status: ${response.statusCode}');

  if (response.statusCode == 200 || response.statusCode == 201) {
    final data = json.decode(response.body);
    print('✅ Message ACCEPTED by WhatsApp API');
    print('Message ID: ${data['messages']?[0]?['id']}');
    print('Contact WA ID: ${data['contacts']?[0]?['wa_id']}');
    print('');
    print('⚠️ "ACCEPTED" means API received the request.');
    print('⚠️ It does NOT guarantee delivery to user!');
    print('⚠️ Check webhook callbacks for delivery status.');
  } else {
    final error = json.decode(response.body);
    print('❌ Message REJECTED');
    print('Error Code: ${error['error']?['code']}');
    print('Error: ${error['error']?['message']}');

    final code = error['error']?['code'];
    if (code == 131030) {
      print('\n⚠️ User not in 24-hour window!');
      print('   User must message your business number first.');
    } else if (code == 131026) {
      print('\n⚠️ Template required for this user!');
      print('   Create an approved message template.');
    }
  }
}
