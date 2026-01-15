// Get WhatsApp Templates using Page ID
import 'package:http/http.dart' as http;
import 'dart:convert';

const String pageId = '709651198900597';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('═══════════════════════════════════════════════════');
  print('📋 Getting WhatsApp Business Account Templates');
  print('═══════════════════════════════════════════════════\n');

  // First, get WABA from the page
  print('1️⃣ Getting WABA from page...');
  await getWabaFromPage();

  print('\n2️⃣ Trying to get templates directly...');
  await getTemplatesDirect();

  print('\n═══════════════════════════════════════════════════');
}

Future<void> getWabaFromPage() async {
  try {
    // Get WhatsApp business accounts
    final url = '$baseUrl/$apiVersion/$pageId/owned_whatsapp_business_accounts';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print('   Status: ${response.statusCode}');
    print('   Response: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final accounts = data['data'] as List? ?? [];
      for (var acc in accounts) {
        print('   WABA ID: ${acc['id']}');
        // Try to get templates for this WABA
        await getTemplatesForWaba(acc['id'].toString());
      }
    }
  } catch (e) {
    print('   Error: $e');
  }
}

Future<void> getTemplatesDirect() async {
  try {
    // Try getting WABA from business
    final businessUrl = '$baseUrl/$apiVersion/me/whatsapp_business_accounts';

    final response = await http.get(
      Uri.parse(businessUrl),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print('   Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   WABAs: ${response.body}');

      final accounts = data['data'] as List? ?? [];
      for (var acc in accounts) {
        await getTemplatesForWaba(acc['id'].toString());
      }
    } else {
      print('   Response: ${response.body}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}

Future<void> getTemplatesForWaba(String wabaId) async {
  try {
    print('\n   📋 Templates for WABA $wabaId:');

    final url = '$baseUrl/$apiVersion/$wabaId/message_templates';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final templates = data['data'] as List? ?? [];

      if (templates.isEmpty) {
        print('   ⚠️ No templates found - You need to create one!');
      } else {
        for (var t in templates) {
          print(
              '   ✅ ${t['name']} - Status: ${t['status']} - Category: ${t['category']}');
        }
      }
    } else {
      print('   Error: ${response.body}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}
