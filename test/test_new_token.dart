// Test new token and create OTP template
import 'package:http/http.dart' as http;
import 'dart:convert';

const String wabaId = '576625715530014';
const String phoneNumberId = '580027788531040';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('=' * 60);
  print('Testing New Token');
  print('=' * 60);

  // 1. Verify token
  print('\n1. Verifying token...');
  final debugUrl =
      '$baseUrl/debug_token?input_token=$accessToken&access_token=$accessToken';
  final tokenResponse = await http.get(Uri.parse(debugUrl));
  final tokenData = json.decode(tokenResponse.body);

  if (tokenResponse.statusCode == 200 &&
      tokenData['data']?['is_valid'] == true) {
    print('   ✅ Token is VALID');
    print('   Type: ${tokenData['data']?['type']}');
    print(
        '   Scopes: ${(tokenData['data']?['scopes'] as List?)?.take(5).join(', ')}...');
  } else {
    print('   ❌ Token is INVALID');
    print('   ${tokenData['error']?['message'] ?? tokenData}');
    return;
  }

  // 2. Check existing templates
  print('\n2. Checking existing templates...');
  final templatesUrl = '$baseUrl/$apiVersion/$wabaId/message_templates';
  final templatesResponse = await http.get(
    Uri.parse(templatesUrl),
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  final templatesData = json.decode(templatesResponse.body);
  if (templatesResponse.statusCode == 200) {
    final templates = templatesData['data'] as List?;
    if (templates != null && templates.isNotEmpty) {
      print('   Found ${templates.length} template(s):');
      for (var t in templates) {
        print('   - ${t['name']} (${t['status']}) - ${t['category']}');
      }
    } else {
      print('   No templates found. Will create OTP template.');
    }
  } else {
    print('   Error: ${templatesData['error']?['message']}');
  }

  // 3. Create OTP template
  print('\n3. Creating OTP Authentication Template...');
  final createResponse = await http.post(
    Uri.parse(templatesUrl),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'name': 'aq_verification_code',
      'category': 'AUTHENTICATION',
      'language': 'en',
      'components': [
        {
          'type': 'BODY',
          'add_security_recommendation': true,
        },
        {
          'type': 'FOOTER',
          'code_expiration_minutes': 10,
        },
        {
          'type': 'BUTTONS',
          'buttons': [
            {'type': 'OTP', 'otp_type': 'COPY_CODE', 'text': 'Copy code'}
          ]
        }
      ]
    }),
  );

  final createData = json.decode(createResponse.body);
  print('   Status: ${createResponse.statusCode}');

  if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
    print('   ✅ Template created successfully!');
    print('   Template ID: ${createData['id']}');
    print('   Status: ${createData['status']}');
  } else {
    print('   ❌ Failed: ${createData['error']?['message']}');
    print('   Error details: ${createData['error']?['error_user_msg']}');

    // Try simpler template
    print('\n   Trying simpler UTILITY template...');
    await createSimpleTemplate(templatesUrl);
  }

  // 4. Send test message
  print('\n4. Sending test message to +972528180757...');
  final sendUrl = '$baseUrl/$apiVersion/$phoneNumberId/messages';
  final sendResponse = await http.post(
    Uri.parse(sendUrl),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'messaging_product': 'whatsapp',
      'to': '972528180757',
      'type': 'text',
      'text': {
        'body': 'Test message from AQ///bimmer Tools - ${DateTime.now()}'
      }
    }),
  );

  final sendData = json.decode(sendResponse.body);
  print('   Status: ${sendResponse.statusCode}');
  if (sendResponse.statusCode == 200) {
    print('   ✅ Message sent! ID: ${sendData['messages']?[0]?['id']}');
  } else {
    print('   ❌ Failed: ${sendData['error']?['message']}');
  }

  print('\n' + '=' * 60);
}

Future<void> createSimpleTemplate(String url) async {
  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'name': 'aq_otp_code',
      'category': 'UTILITY',
      'language': 'en',
      'components': [
        {'type': 'HEADER', 'format': 'TEXT', 'text': 'Verification Code'},
        {
          'type': 'BODY',
          'text':
              'Your verification code is {{1}}. This code expires in 10 minutes. Do not share this code with anyone.',
          'example': {
            'body_text': [
              ['123456']
            ]
          }
        },
        {'type': 'FOOTER', 'text': 'AQ///bimmer Tools'}
      ]
    }),
  );

  final data = json.decode(response.body);
  print('   Status: ${response.statusCode}');
  if (response.statusCode == 200 || response.statusCode == 201) {
    print('   ✅ Simple template created! ID: ${data['id']}');
  } else {
    print('   ❌ Failed: ${data['error']?['message']}');
    print('   Details: ${data['error']?['error_user_msg']}');
  }
}
