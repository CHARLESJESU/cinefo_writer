import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple API helper for VCID write calls.
///
/// This class contains pure network logic only. It does not call UI
/// helpers (showDialog/snackbars) or call setState. Callers should handle
/// UI updates based on the returned result or thrown exceptions.
class Apicalls {
static Future<Map<String, dynamic>> fetchDataAndWriteVcid(
      String vcidString, String rfid) async {
    // Validate VCID: caller passed a String, convert to int
    final int? vcid = int.tryParse(vcidString);
    if (vcid == null) throw FormatException('Invalid VCID: $vcidString');

    final String apiUrl =
        'https://vpack.vframework.in/vpackapi/Subscription/v1/registermininfc';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'vcid': vcid, 'rfid': rfid}),
      );
print("maaaaaaaaaaaaaaaaaaaaaaasss");
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception(
            'Server returned status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // Re-throw to let the caller decide how to present the error.
      rethrow;
    }
  }
}