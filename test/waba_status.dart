// Check WABA Status and provide solution
import 'package:http/http.dart' as http;
import 'dart:convert';

const String wabaId = '576625715530014';
const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('=' * 70);
  print('WHATSAPP BUSINESS ACCOUNT STATUS CHECK');
  print('=' * 70);

  // Check WABA status
  print('\n1. WABA Account Status:');
  final wabaUrl =
      '$baseUrl/$apiVersion/$wabaId?fields=id,name,currency,timezone_id,account_review_status,business_verification_status,ownership_type';
  await checkStatus(wabaUrl);

  // Check phone number status
  print('\n2. Phone Number Status:');
  final phoneUrl =
      '$baseUrl/$apiVersion/$phoneNumberId?fields=id,display_phone_number,verified_name,name_status,quality_rating,code_verification_status,messaging_limit_tier,certificate,is_official_business_account,account_mode';
  await checkStatus(phoneUrl);

  // Check WABA phone numbers
  print('\n3. WABA Phone Numbers:');
  final numbersUrl = '$baseUrl/$apiVersion/$wabaId/phone_numbers';
  await checkStatus(numbersUrl);

  // Print solution
  print('\n');
  print('=' * 70);
  print('SOLUTION - HOW TO FIX:');
  print('=' * 70);
  print('''

The problem: Your WABA ($wabaId) has NO message templates.
WhatsApp Business API requires approved templates to message users
who haven't messaged you in the last 24 hours.

TO FIX THIS, YOU HAVE 2 OPTIONS:

OPTION 1: Create a Message Template (Recommended)
-------------------------------------------------
1. Go to: https://business.facebook.com/wa/manage/message-templates/
2. Select your WhatsApp Business Account: AQ///bimmer
3. Click "Create Template"
4. Choose Category: "Authentication" (for OTP)
5. Template Name: "verification_code" (lowercase, no spaces)
6. Language: English (or your preferred language)
7. Body: "Your verification code is {{1}}. Valid for 10 minutes."
8. Submit for review (usually approved within minutes)

OPTION 2: User Initiates Contact First
--------------------------------------
1. Tell your users to first send a message to: +972 52-486-4281
2. After they message, you have 24 hours to send them messages
3. This is the "Customer Care Window"

OPTION 3: Use the Test WABA Account
-----------------------------------
Your test WABA ($wabaId) has approved templates.
You could use templates from Test WABA but need to:
1. Move the phone number to the test WABA, or
2. Create similar templates in the main WABA

DIRECT LINKS:
- Message Templates: https://business.facebook.com/wa/manage/message-templates/?waba_id=$wabaId
- WhatsApp Manager: https://business.facebook.com/wa/manage/
- Meta Business Suite: https://business.facebook.com/

''');
}

Future<void> checkStatus(String url) async {
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200) {
      print('   ${const JsonEncoder.withIndent('   ').convert(data)}');
    } else {
      print('   Error: ${data['error']?['message']}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}
