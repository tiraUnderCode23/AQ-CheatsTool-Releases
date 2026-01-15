// Find WABA via Business ID
import 'package:http/http.dart' as http;
import 'dart:convert';

const String businessId = '1396464028690689';
const String accessToken =
    'EAAeA3FDAMxkBQX00uSGUberQ9Tyun0m7Hn6jkZB0PZCCc9rZBSJWY5ZAQsJTAwUZADsyTFZBPHPXrYQJXZBXv3tPYON18acQtnBjaDmHW7sR1obH9sJhRSnZAf4yhglHOSZBXHJ5DuPHgEPxKosh3gsr2b48ZAjFeHVKVStZAAVYdypIuOjUPLXMhDSa8aeZBar8JorqhgKiMpQ0MyZBY5QDFvn2qLGHszNzBWGLVyAdV';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('Finding WABA via Business ID: $businessId\n');

  // Get business owned WABAs
  print('1. Business owned WABAs...');
  final url1 =
      '$baseUrl/$apiVersion/$businessId/owned_whatsapp_business_accounts';
  await makeRequest(url1);

  // Get client WABAs
  print('\n2. Client WABAs...');
  final url2 =
      '$baseUrl/$apiVersion/$businessId/client_whatsapp_business_accounts';
  await makeRequest(url2);

  // Get business details
  print('\n3. Business details...');
  final url3 = '$baseUrl/$apiVersion/$businessId?fields=id,name,created_time';
  await makeRequest(url3);

  // Get system users
  print('\n4. System users...');
  final url4 = '$baseUrl/$apiVersion/$businessId/system_users';
  await makeRequest(url4);

  // Get owned apps
  print('\n5. Owned apps...');
  final url5 = '$baseUrl/$apiVersion/$businessId/owned_apps';
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
