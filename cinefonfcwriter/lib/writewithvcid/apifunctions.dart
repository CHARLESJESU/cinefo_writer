import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple API helper for VCID write calls.
///
/// This class contains pure network logic only. It does not call UI
/// helpers (showDialog/snackbars) or call setState. Callers should handle
/// UI updates based on the returned result or thrown exceptions.
class Apicalls {

  /// Call the service that returns the encrypted VCID for a given VCID input.
  ///
  /// Returns the encrypted VCID as a String on success. Throws an Exception
  /// on any non-200 response or unexpected/missing data.
  static Future<String> sendencryptVcidToAPI(String vcid) async {
    final String apiUrl = "https://vpack.vframework.in/vpackapi/Card/writeNFCinfo";
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"data": vcid}),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }

      // Parse body safely and provide helpful error on malformed JSON
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (_) {
        throw Exception('Invalid JSON from sendencryptVcidToAPI: ${response.body}');
      }

      if (decoded is Map && decoded['statusdescription'] == 'Success') {
        final responseData = decoded['responseData'];
        if (responseData != null && responseData['vcid'] != null) {
          return responseData['vcid'].toString();
        }
        throw Exception('Missing vcid in response: ${response.body}');
      }

      throw Exception(decoded is Map && decoded['statusdescription'] != null
          ? decoded['statusdescription'].toString()
          : 'Unknown error: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> fetchDataAndWriteVcid(
      String vcidString, String rfid) async {
    // The encryption endpoint may return an encrypted VCID which can be
    // alphanumeric. Send it as-is to the registration endpoint. If the
    // backend expects a numeric VCID, change the encrypt call or backend
    // accordingly.
    final String apiUrl =
        'https://vpack.vframework.in/vpackapi/Subscription/v1/registermininfc';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'vcid': vcidString, 'rfid': rfid}),
      );
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (_) {
        throw Exception('Invalid JSON from fetchDataAndWriteVcid: ${response.body}');
      }

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Unexpected response format: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }
}