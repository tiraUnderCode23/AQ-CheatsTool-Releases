// Complete WhatsApp Template Setup and Configuration
// This script will create templates and update the app configuration
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String wabaId = '576625715530014';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('');
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║     🔧 Complete WhatsApp Template Setup                       ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');

  // Step 1: Delete rejected templates
  print('1️⃣ Cleaning up rejected templates...');
  await deleteRejectedTemplates();
  print('');

  // Step 2: Create new OTP template with correct format
  print('2️⃣ Creating OTP templates...');
  String? workingTemplate = await createOtpTemplates();
  print('');

  // Step 3: List all templates
  print('3️⃣ Current templates status:');
  await listAllTemplates();
  print('');

  // Step 4: Test the working template
  if (workingTemplate != null) {
    print('4️⃣ Testing template: $workingTemplate');
    await testTemplate(workingTemplate, '972528180757');
  }

  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('✅ Setup complete!');
  print('═══════════════════════════════════════════════════════════════');
}

Future<void> deleteRejectedTemplates() async {
  final rejectedTemplates = [
    'aq_otp_code',
    'aq_activation_key',
    'aq_utility_code',
  ];

  for (var name in rejectedTemplates) {
    try {
      final url = '$baseUrl/$apiVersion/$wabaId/message_templates?name=$name';
      final response = await http.delete(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        print('   🗑️ Deleted: $name');
      } else {
        print('   ⚠️ Could not delete $name (may not exist)');
      }
    } catch (e) {
      print('   ⚠️ Error deleting $name');
    }
  }
}

Future<String?> createOtpTemplates() async {
  final url = '$baseUrl/$apiVersion/$wabaId/message_templates';
  String? workingTemplate;

  // Template 1: UTILITY with proper OTP format
  print('   📝 Creating aq_otp_verify (UTILITY)...');
  var template = {
    'name': 'aq_otp_verify',
    'category': 'UTILITY',
    'language': 'en',
    'components': [
      {
        'type': 'BODY',
        'text':
            'Your AQ///bimmer verification code is *{{1}}*. This code will expire in 5 minutes. Please do not share this code with anyone for your security.',
        'example': {
          'body_text': [
            ['123456']
          ]
        }
      },
      {'type': 'FOOTER', 'text': 'AQ///bimmer Tools'}
    ]
  };

  var result = await submitTemplate(url, template);
  if (result != null) workingTemplate = result;

  // Template 2: UTILITY simpler version
  if (workingTemplate == null) {
    print('   📝 Creating aq_code_verify (UTILITY)...');
    template = {
      'name': 'aq_code_verify',
      'category': 'UTILITY',
      'language': 'en',
      'components': [
        {
          'type': 'BODY',
          'text':
              'Hello! Your verification code for AQ///bimmer is: *{{1}}*. This code expires in 5 minutes.',
          'example': {
            'body_text': [
              ['123456']
            ]
          }
        }
      ]
    };

    result = await submitTemplate(url, template);
    if (result != null) workingTemplate = result;
  }

  // Template 3: MARKETING with copy code button
  if (workingTemplate == null) {
    print('   📝 Creating aq_verification_code (MARKETING)...');
    template = {
      'name': 'aq_verification_code',
      'category': 'MARKETING',
      'language': 'en',
      'components': [
        {
          'type': 'BODY',
          'text':
              'Welcome to AQ///bimmer! Your verification code is: *{{1}}*. Enter this code to complete your registration.',
          'example': {
            'body_text': [
              ['123456']
            ]
          }
        },
        {
          'type': 'BUTTONS',
          'buttons': [
            {'type': 'COPY_CODE', 'example': '123456'}
          ]
        }
      ]
    };

    result = await submitTemplate(url, template);
    if (result != null) workingTemplate = result;
  }

  // Template 4: Simple MARKETING
  if (workingTemplate == null) {
    print('   📝 Creating aq_verify_user (MARKETING)...');
    template = {
      'name': 'aq_verify_user',
      'category': 'MARKETING',
      'language': 'en',
      'components': [
        {
          'type': 'BODY',
          'text':
              'Thank you for using AQ///bimmer Tools! Your security code is: *{{1}}*. Valid for 5 minutes.',
          'example': {
            'body_text': [
              ['123456']
            ]
          }
        }
      ]
    };

    result = await submitTemplate(url, template);
    if (result != null) workingTemplate = result;
  }

  return workingTemplate;
}

Future<String?> submitTemplate(
    String url, Map<String, dynamic> template) async {
  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(template),
    );

    final data = json.decode(response.body);
    final name = template['name'] as String;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final status = data['status'] ?? 'PENDING';
      print('      ✅ Created: $name (Status: $status)');

      if (status == 'APPROVED') {
        return name;
      }
      return null; // Pending approval
    } else {
      final error = data['error'];
      final errorCode = error?['code'];

      // Template already exists
      if (errorCode == 2388094) {
        print('      ℹ️ Already exists: $name');
        return name;
      }

      print('      ❌ Failed: ${error?['message']}');
      if (error?['error_user_msg'] != null) {
        print('         Reason: ${error['error_user_msg']}');
      }
      return null;
    }
  } catch (e) {
    print('      ❌ Error: $e');
    return null;
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
      print('   ┌─────────────────────────────────────────────────────────┐');

      for (var t in templates) {
        final name = t['name'];
        final status = t['status'];
        final category = t['category'];

        String icon;
        switch (status) {
          case 'APPROVED':
            icon = '✅';
            break;
          case 'PENDING':
            icon = '⏳';
            break;
          default:
            icon = '❌';
        }

        print('   │ $icon $name');
        print('   │    Category: $category | Status: $status');

        // Check for {{1}} parameter
        final components = t['components'] as List? ?? [];
        for (var c in components) {
          if (c['type'] == 'BODY') {
            final text = c['text'] as String? ?? '';
            final hasParam = text.contains('{{1}}');
            print('   │    Has OTP param: ${hasParam ? '✅' : '❌'}');
            break;
          }
        }
        print('   │');
      }

      print('   └─────────────────────────────────────────────────────────┘');

      // Find best template for OTP
      print('');
      print('   🎯 Best templates for OTP:');
      for (var t in templates) {
        if (t['status'] == 'APPROVED') {
          final components = t['components'] as List? ?? [];
          for (var c in components) {
            if (c['type'] == 'BODY') {
              final text = c['text'] as String? ?? '';
              if (text.contains('{{1}}')) {
                print('      → ${t['name']}');
              }
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

Future<void> testTemplate(String templateName, String phone) async {
  try {
    final url = '$baseUrl/$apiVersion/$phoneNumberId/messages';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'messaging_product': 'whatsapp',
        'to': phone,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {'code': 'en'},
          'components': [
            {
              'type': 'body',
              'parameters': [
                {'type': 'text', 'text': '12345'}
              ]
            }
          ]
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   ✅ Test message sent!');
      print('   Message ID: ${data['messages']?[0]?['id']}');
    } else {
      final data = json.decode(response.body);
      print('   ❌ Failed: ${data['error']?['message']}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}
