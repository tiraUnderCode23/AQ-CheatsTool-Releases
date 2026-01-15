// Fetch Available Templates and Update Service Configuration
import 'package:http/http.dart' as http;
import 'dart:convert';

// WhatsApp Business API Configuration
const String phoneNumberId = '580027788531040';
const String wabaId = '576625715530014'; // AQ///bimmer WABA

// Use the latest access token from the service file
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';

const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('');
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║     📋 WhatsApp Message Templates - Fetch & Analyze          ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');

  // Step 1: Verify API Token
  print('1️⃣ Verifying API Token...');
  final isValid = await verifyToken();
  if (!isValid) {
    print('   ❌ Token is invalid or expired!');
    print('   Please update the access token.');
    return;
  }
  print('   ✅ Token is valid\n');

  // Step 2: Get WABA Info
  print('2️⃣ Getting WhatsApp Business Account Info...');
  await getWabaInfo();
  print('');

  // Step 3: Fetch All Templates
  print('3️⃣ Fetching Message Templates...');
  final templates = await fetchTemplates();
  print('');

  // Step 4: Analyze Templates for OTP
  print('4️⃣ Analyzing Templates for OTP Usage...');
  analyzeTemplatesForOtp(templates);
  print('');

  // Step 5: Show Recommendations
  print('5️⃣ Recommendations for OTP Template Configuration:');
  showRecommendations(templates);
}

Future<bool> verifyToken() async {
  try {
    final url = '$baseUrl/$apiVersion/$phoneNumberId';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   📱 Phone: ${data['display_phone_number'] ?? 'N/A'}');
      print('   📛 Name: ${data['verified_name'] ?? 'N/A'}');
      return true;
    } else {
      final error = json.decode(response.body);
      print('   Error: ${error['error']?['message']}');
      return false;
    }
  } catch (e) {
    print('   Error: $e');
    return false;
  }
}

Future<Map<String, dynamic>?> getWabaInfo() async {
  try {
    final url = '$baseUrl/$apiVersion/$wabaId';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   🏢 WABA ID: ${data['id'] ?? wabaId}');
      print('   📛 Name: ${data['name'] ?? 'N/A'}');
      print('   💰 Currency: ${data['currency'] ?? 'N/A'}');
      return data;
    } else {
      print(
          '   ⚠️ Could not fetch WABA info (this is normal for some accounts)');
      return null;
    }
  } catch (e) {
    print('   Error: $e');
    return null;
  }
}

Future<List<Map<String, dynamic>>> fetchTemplates() async {
  final templates = <Map<String, dynamic>>[];

  try {
    final url = '$baseUrl/$apiVersion/$wabaId/message_templates?limit=100';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print('   Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final templateList = data['data'] as List? ?? [];

      if (templateList.isEmpty) {
        print('   ⚠️ No templates found in this WABA');
        print('');
        print('   📝 You need to create an OTP template!');
        print(
            '   Go to: https://business.facebook.com/wa/manage/message-templates/');
      } else {
        print('   ✅ Found ${templateList.length} template(s):\n');

        for (var t in templateList) {
          templates.add(Map<String, dynamic>.from(t));

          final name = t['name'] ?? 'Unknown';
          final status = t['status'] ?? 'Unknown';
          final category = t['category'] ?? 'Unknown';
          final language = t['language'] ?? 'Unknown';

          String statusIcon;
          switch (status) {
            case 'APPROVED':
              statusIcon = '✅';
              break;
            case 'PENDING':
              statusIcon = '⏳';
              break;
            case 'REJECTED':
              statusIcon = '❌';
              break;
            default:
              statusIcon = '❓';
          }

          print('   ┌─────────────────────────────────────────────');
          print('   │ $statusIcon Template: $name');
          print('   │    Status: $status');
          print('   │    Category: $category');
          print('   │    Language: $language');

          // Show components
          final components = t['components'] as List? ?? [];
          for (var comp in components) {
            final type = comp['type'] ?? 'Unknown';
            final text = comp['text'] ?? comp['format'] ?? '';
            if (text.isNotEmpty) {
              print('   │    $type: $text');
            }
          }
          print('   └─────────────────────────────────────────────');
          print('');
        }
      }
    } else {
      final error = json.decode(response.body);
      print('   ❌ Error: ${error['error']?['message']}');
    }
  } catch (e) {
    print('   Error: $e');
  }

  return templates;
}

void analyzeTemplatesForOtp(List<Map<String, dynamic>> templates) {
  final otpTemplates = <Map<String, dynamic>>[];
  final approvedTemplates = <Map<String, dynamic>>[];

  for (var t in templates) {
    final status = t['status'];
    final category = t['category'];
    final name = t['name'] as String? ?? '';

    if (status == 'APPROVED') {
      approvedTemplates.add(t);

      // Check if it's suitable for OTP
      if (category == 'AUTHENTICATION' ||
          name.contains('otp') ||
          name.contains('verification') ||
          name.contains('code') ||
          name.contains('auth')) {
        otpTemplates.add(t);
      }
    }
  }

  print('   📊 Analysis Results:');
  print('   ────────────────────────────────────────');
  print('   Total templates: ${templates.length}');
  print('   Approved templates: ${approvedTemplates.length}');
  print('   OTP-suitable templates: ${otpTemplates.length}');
  print('');

  if (otpTemplates.isNotEmpty) {
    print('   🎯 Best templates for OTP:');
    for (var t in otpTemplates) {
      print('      • ${t['name']} (${t['category']})');
    }
  } else if (approvedTemplates.isNotEmpty) {
    print('   ⚠️ No dedicated OTP templates found.');
    print('   You can use these approved templates:');
    for (var t in approvedTemplates) {
      print('      • ${t['name']} (${t['category']})');
    }
  } else {
    print('   ❌ No approved templates available!');
    print('   You must create and get approval for an OTP template.');
  }
}

void showRecommendations(List<Map<String, dynamic>> templates) {
  print('   ════════════════════════════════════════════════════════');
  print('');

  // Find the best template to use
  String? recommendedTemplate;
  for (var t in templates) {
    if (t['status'] == 'APPROVED') {
      final name = t['name'] as String;
      if (t['category'] == 'AUTHENTICATION') {
        recommendedTemplate = name;
        break;
      }
      recommendedTemplate ??= name;
    }
  }

  if (recommendedTemplate != null) {
    print('   ✅ RECOMMENDED TEMPLATE: $recommendedTemplate');
    print('');
    print('   Update your whatsapp_business_api_service.dart:');
    print('');
    print('   static const List<String> _otpTemplateNames = [');
    print("     '$recommendedTemplate',  // Your approved template");
    print("     'verification_code',");
    print("     'otp_code',");
    print('   ];');
    print('');
  } else {
    print('   ❌ NO APPROVED TEMPLATES FOUND');
    print('');
    print('   Please create an OTP template in Meta Business Suite:');
    print('');
    print('   📋 Steps to create OTP template:');
    print('   ─────────────────────────────────────────────');
    print(
        '   1. Go to: https://business.facebook.com/wa/manage/message-templates/');
    print('   2. Click "Create Template"');
    print('   3. Category: AUTHENTICATION (recommended for OTP)');
    print('   4. Name: aq_otp_verification');
    print('   5. Language: English (en) or Arabic (ar)');
    print('');
    print('   📝 Recommended Template Body (English):');
    print('   ─────────────────────────────────────────────');
    print('   "Your AQ///bimmer verification code is: {{1}}');
    print('');
    print('   This code expires in 5 minutes.');
    print('   Do not share this code with anyone."');
    print('');
    print('   📝 Recommended Template Body (Arabic):');
    print('   ─────────────────────────────────────────────');
    print('   "رمز التحقق الخاص بك في AQ///bimmer هو: {{1}}');
    print('');
    print('   ينتهي هذا الرمز خلال 5 دقائق.');
    print('   لا تشارك هذا الرمز مع أي شخص."');
    print('');
  }

  print('   ════════════════════════════════════════════════════════');
  print('');
  print('   📌 IMPORTANT NOTES:');
  print('   ─────────────────────────────────────────────');
  print('   • AUTHENTICATION templates are auto-approved by Meta');
  print('   • For new contacts, ONLY template messages work');
  print('   • Regular text messages require user to message first');
  print('   • Template approval usually takes 1-24 hours');
  print('');
}
