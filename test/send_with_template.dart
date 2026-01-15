// Send OTP using Template
import 'package:http/http.dart' as http;
import 'dart:convert';

const String phoneNumberId = '580027788531040';
const String wabaId = '576625715530014';
const String accessToken =
    'EAAeA3FDAMxkBQRzdmcnezP6hV7WVZC8OZAiUUhH9ZBYDyc0EmvN1BT4yu8QKgLBNDiIq2RN3gb1zmX28h3Hvlzd3lfiuLzeCMfAFtQbHqd1mMYlXt7WaIjtxtreSZBEvlVe6qWQspqbM1OAxAGHApTRQqTu7ri4Ney7Qo5r2OFYIgjJznfmsn3qlkZCt1DQZDZD';
const String apiVersion = 'v22.0';
const String baseUrl = 'https://graph.facebook.com';

Future<void> main() async {
  print('=' * 60);
  print('CHECKING ALL TEMPLATES');
  print('=' * 60);

  // First, get all templates
  final templatesUrl =
      '$baseUrl/$apiVersion/$wabaId/message_templates?limit=100';
  final templatesResponse = await http.get(
    Uri.parse(templatesUrl),
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  final templatesData = json.decode(templatesResponse.body);
  print('\nAll Templates:');

  String? approvedTemplateName;
  String? approvedTemplateLanguage;

  if (templatesResponse.statusCode == 200) {
    final templates = templatesData['data'] as List?;
    if (templates != null) {
      for (var t in templates) {
        final status = t['status'];
        final name = t['name'];
        final lang = t['language'];
        final icon =
            status == 'APPROVED' ? '✅' : (status == 'PENDING' ? '⏳' : '❌');
        print('  $icon $name ($lang) - $status');

        // Find first approved template
        if (status == 'APPROVED' && approvedTemplateName == null) {
          approvedTemplateName = name;
          approvedTemplateLanguage = lang;
        }
      }
    }
  }

  // Check if there's a new template you created
  print('\n' + '=' * 60);
  print('Looking for verification_code template...');

  // Search for common OTP template names
  final commonNames = [
    'verification_code',
    'otp_code',
    'otp',
    'verification',
    'auth_code'
  ];
  for (var name in commonNames) {
    final searchUrl =
        '$baseUrl/$apiVersion/$wabaId/message_templates?name=$name';
    final searchResponse = await http.get(
      Uri.parse(searchUrl),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final searchData = json.decode(searchResponse.body);
    final found = searchData['data'] as List?;
    if (found != null && found.isNotEmpty) {
      print('  Found: $name - ${found[0]['status']}');
      if (found[0]['status'] == 'APPROVED') {
        approvedTemplateName = name;
        approvedTemplateLanguage = found[0]['language'];
      }
    }
  }

  print('\n' + '=' * 60);

  if (approvedTemplateName != null) {
    print('SENDING OTP USING TEMPLATE: $approvedTemplateName');
    print('=' * 60);

    // Send using template
    final sendUrl = '$baseUrl/$apiVersion/$phoneNumberId/messages';
    final otp = '54321';

    final response = await http.post(
      Uri.parse(sendUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'messaging_product': 'whatsapp',
        'to': '972528180757',
        'type': 'template',
        'template': {
          'name': approvedTemplateName,
          'language': {'code': approvedTemplateLanguage ?? 'en'},
          'components': [
            {
              'type': 'body',
              'parameters': [
                {'type': 'text', 'text': otp}
              ]
            }
          ]
        }
      }),
    );

    final data = json.decode(response.body);
    print('\nStatus: ${response.statusCode}');
    print('Response: ${const JsonEncoder.withIndent('  ').convert(data)}');

    if (response.statusCode == 200) {
      print('\n✅ Template message sent!');
    } else {
      print('\n❌ Failed to send template message');
    }
  } else {
    print('NO APPROVED TEMPLATES FOUND!');
    print('=' * 60);
    print('\nPlease tell me the name of the template you created.');
    print('You can find it at:');
    print(
        'https://business.facebook.com/wa/manage/message-templates/?waba_id=$wabaId');
  }
}
