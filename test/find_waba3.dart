// Find WABA via App
import 'package:http/http.dart' as http;
import 'dart:convert';

const String appId = '2112008572908313';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('Finding WABA via App...\n');

  // Try to get WABA subscribed apps
  print('1. App subscribed WABAs...');
  final url1 =
      '$baseUrl/$apiVersion/$appId/subscribed_whatsapp_business_accounts';
  await makeRequest(url1);

  // Try getting WABA from system user assets
  print('\n2. System user assets...');
  final userId = '122105239143201499';
  final url2 = '$baseUrl/$apiVersion/$userId/assigned_pages';
  await makeRequest(url2);

  // Try shared wabas
  print('\n3. Shared WABAs...');
  final url3 = '$baseUrl/$apiVersion/$appId?fields=whatsapp_business_accounts';
  await makeRequest(url3);

  // Try via assigned ad accounts
  print('\n4. Assigned ad accounts...');
  final url4 = '$baseUrl/$apiVersion/$userId/assigned_ad_accounts';
  await makeRequest(url4);

  // Try system user wa accounts
  print('\n5. System user assigned_product_catalogs...');
  final url5 = '$baseUrl/$apiVersion/$userId/assigned_business_asset_groups';
  await makeRequest(url5);

  // Try phone number owner info
  print('\n6. Phone number owner...');
  const phoneNumberId = '580027788531040';
  final url6 = '$baseUrl/$apiVersion/$phoneNumberId?fields=owner';
  await makeRequest(url6);

  print('\n═══════════════════════════════════════════════════');
  print('الحل النهائي:');
  print('═══════════════════════════════════════════════════\n');
  print('للاسف الـ API لا يوفر طريقة مباشرة للحصول على WABA ID');
  print('من خلال الـ Token الحالي.');
  print('');
  print('الحلول المتاحة:');
  print('');
  print('1. ارسل رسالة من هاتفك الى رقم الاعمال:');
  print('   +972 52-486-4281');
  print('   ثم يمكن للتطبيق ارسال رسائل لك خلال 24 ساعة');
  print('');
  print('2. اذهب الى Meta Business Suite وانشئ template رسالة:');
  print('   https://business.facebook.com/wa/manage/');
  print('');
  print('3. او استخدم هذا الرابط مباشرة لانشاء template:');
  print(
      '   https://business.facebook.com/latest/whatsapp_manager/message_templates');
  print('');
}

Future<void> makeRequest(String url) async {
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print('   Status: ${response.statusCode}');
    final data = json.decode(response.body);
    if (response.statusCode == 200) {
      print('   OK: ${const JsonEncoder.withIndent('      ').convert(data)}');
    } else {
      print('   Error: ${data['error']?['message'] ?? response.body}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}
