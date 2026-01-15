// Create AUTHENTICATION Template with correct format
// Meta requires specific structure for authentication templates
import 'package:http/http.dart' as http;
import 'dart:convert';

const String wabaId = '576625715530014';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('');
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║     🔐 Creating Authentication Template (Correct Format)      ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');

  final url = '$baseUrl/$apiVersion/$wabaId/message_templates';

  // Method 1: Authentication template with COPY_CODE button
  // Per Meta docs: https://developers.facebook.com/docs/whatsapp/business-management-api/authentication-templates
  print('1️⃣ Method 1: Copy Code Button...');

  var template = {
    'name': 'aq_auth_otp',
    'category': 'AUTHENTICATION',
    'language': 'en',
    'components': [
      {'type': 'BODY', 'add_security_recommendation': true},
      {
        'type': 'BUTTONS',
        'buttons': [
          {'type': 'OTP', 'otp_type': 'COPY_CODE', 'text': 'Copy code'}
        ]
      }
    ]
  };

  var success = await createTemplate(url, template);

  if (!success) {
    // Method 2: With footer
    print('\n2️⃣ Method 2: With expiry footer...');

    template = {
      'name': 'aq_auth_verify',
      'category': 'AUTHENTICATION',
      'language': 'en',
      'components': [
        {'type': 'BODY', 'add_security_recommendation': true},
        {'type': 'FOOTER', 'code_expiration_minutes': 5},
        {
          'type': 'BUTTONS',
          'buttons': [
            {'type': 'OTP', 'otp_type': 'COPY_CODE', 'text': 'Copy code'}
          ]
        }
      ]
    };

    success = await createTemplate(url, template);
  }

  if (!success) {
    // Method 3: One-tap autofill
    print('\n3️⃣ Method 3: One-tap autofill button...');

    template = {
      'name': 'aq_auth_autofill',
      'category': 'AUTHENTICATION',
      'language': 'en',
      'components': [
        {'type': 'BODY', 'add_security_recommendation': true},
        {
          'type': 'BUTTONS',
          'buttons': [
            {
              'type': 'OTP',
              'otp_type': 'ONE_TAP',
              'text': 'Autofill',
              'autofill_text': 'Autofill',
              'package_name': 'com.aqbimmer.tool',
              'signature_hash': 'ABC123' // Will need real hash
            }
          ]
        }
      ]
    };

    success = await createTemplate(url, template);
  }

  if (!success) {
    // Method 4: UTILITY category (longer text to pass validation)
    print('\n4️⃣ Method 4: UTILITY with longer text...');

    template = {
      'name': 'aq_utility_code',
      'category': 'UTILITY',
      'language': 'en',
      'components': [
        {
          'type': 'BODY',
          'text':
              'Hello! Your AQ///bimmer verification code is: {{1}}. This code will expire in 5 minutes. Please do not share this code with anyone for security reasons.',
          'example': {
            'body_text': [
              ['123456']
            ]
          }
        }
      ]
    };

    success = await createTemplate(url, template);
  }

  if (!success) {
    // Method 5: MARKETING with OTP-like message
    print('\n5️⃣ Method 5: MARKETING template...');

    template = {
      'name': 'aq_verify_code',
      'category': 'MARKETING',
      'language': 'en',
      'components': [
        {
          'type': 'BODY',
          'text':
              'Welcome to AQ///bimmer! Your verification code is: {{1}}. This code expires in 5 minutes. Thank you for using our service.',
          'example': {
            'body_text': [
              ['123456']
            ]
          }
        }
      ]
    };

    success = await createTemplate(url, template);
  }

  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('📋 Final Template Status:');
  await listAllTemplates();
  print('═══════════════════════════════════════════════════════════════');
}

Future<bool> createTemplate(String url, Map<String, dynamic> template) async {
  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(template),
    );

    print('   Name: ${template['name']}');
    print('   Category: ${template['category']}');
    print('   Status Code: ${response.statusCode}');

    final data = json.decode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('   ✅ SUCCESS! Template created');
      print('   ID: ${data['id']}');
      print('   Status: ${data['status'] ?? 'PENDING'}');
      return true;
    } else {
      final error = data['error'];
      print('   ❌ Failed: ${error?['message']}');
      if (error?['error_user_msg'] != null) {
        print('   Reason: ${error['error_user_msg']}');
      }
      return false;
    }
  } catch (e) {
    print('   ❌ Exception: $e');
    return false;
  }
}

Future<void> listAllTemplates() async {
  try {
    final url = '$baseUrl/$apiVersion/$wabaId/message_templates?limit=100';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final templates = data['data'] as List? ?? [];

      print('');
      print('   Found ${templates.length} templates:');
      print('');

      // Separate by status
      final approved = <String>[];
      final pending = <String>[];
      final rejected = <String>[];

      for (var t in templates) {
        final name = t['name'];
        final status = t['status'];
        final category = t['category'];
        final info = '$name ($category)';

        switch (status) {
          case 'APPROVED':
            approved.add(info);
            break;
          case 'PENDING':
            pending.add(info);
            break;
          default:
            rejected.add(info);
        }
      }

      if (approved.isNotEmpty) {
        print('   ✅ APPROVED:');
        for (var t in approved) {
          print('      • $t');
        }
      }

      if (pending.isNotEmpty) {
        print('   ⏳ PENDING:');
        for (var t in pending) {
          print('      • $t');
        }
      }

      if (rejected.isNotEmpty) {
        print('   ❌ REJECTED:');
        for (var t in rejected) {
          print('      • $t');
        }
      }

      // Find best OTP template
      print('');
      print('   🎯 Best template for OTP:');
      for (var t in templates) {
        if (t['status'] == 'APPROVED') {
          final components = t['components'] as List? ?? [];
          for (var c in components) {
            final text = c['text'] as String? ?? '';
            if (text.contains('{{1}}') ||
                text.contains('code') ||
                text.contains('verification')) {
              print('      → ${t['name']}');
              print(
                  '        Body: ${text.length > 80 ? text.substring(0, 80) + '...' : text}');
              break;
            }
          }
        }
      }
    }
  } catch (e) {
    print('   Error: $e');
  }
}
