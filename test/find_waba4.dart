// Find WABA via Page
import 'package:http/http.dart' as http;
import 'dart:convert';

const String pageId = '709651198900597';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('Finding WABA via Page...\n');

  // Get page details
  print('1. Page details with businesses...');
  final url1 = '$baseUrl/$apiVersion/$pageId?fields=id,name,business,link';
  await makeRequest(url1);

  // Get page connected WABA
  print('\n2. Page connected WABA...');
  final url2 =
      '$baseUrl/$apiVersion/$pageId?fields=connected_instagram_account,whatsapp_business_accounts';
  await makeRequest(url2);

  // Get businesses
  print('\n3. Page businesses...');
  final url3 = '$baseUrl/$apiVersion/$pageId/businesses';
  await makeRequest(url3);

  // Try to get WABA directly
  print('\n4. Try WABA directly via page...');
  final url4 = '$baseUrl/$apiVersion/$pageId/linked_whatsapp_business_accounts';
  await makeRequest(url4);

  // Get all pages
  print('\n5. All accessible pages...');
  final url5 = '$baseUrl/$apiVersion/me/accounts?fields=id,name,access_token';
  await makeRequest(url5);
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
