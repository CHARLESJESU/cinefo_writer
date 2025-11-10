import 'dart:convert';
import 'dart:typed_data';

import 'package:cinefonfcwriter/assets/variables.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:http/http.dart' as http;
import 'package:cinefonfcwriter/writewithvcid/apifunctions.dart';

class VCID extends StatefulWidget {
  const VCID({super.key});

  @override
  State<VCID> createState() => _VCIDState();
}

class _VCIDState extends State<VCID> {
  Map? responsedata;
  Map? responsedata1;
  bool isProcessing = false;
  bool isBuffering = false;
  String? firstresponsedata;
  Future<void> firstapi() async {
    String apiUrl = "https://vcrypt.vframework.in/vcryptapi/smallencrypt";
    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"data": writewithcodevcid}),
      );

      if (response.statusCode == 200) {
        print(response.body);
        responsedata = jsonDecode(response.body);
        responsedata1 = responsedata!['data'];
        if (responsedata1!['response_description'] == "Success") {
          firstresponsedata = responsedata1!['data'];
          sendVcidToAPI();
        } else {
          showSimplePopUp(context, responsedata!['statusdescription']);
        }
      } else {
        showError("Error fetching details");
      }
    } catch (e) {
      showError("Error: $e");
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> sendVcidToAPI() async {
    String apiUrl = "https://vpack.vframework.in/vpackapi/Card/writeNFCinfo";
    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"data": firstresponsedata}),
      );

      if (response.statusCode == 200) {
        responsedata = jsonDecode(response.body);
        responsedata1 = responsedata!['responseData'];
        if (responsedata!['statusdescription'] == "Success") {
          showConfirmationDialog();
        } else {
          showSimplePopUp(context, responsedata!['statusdescription']);
        }
      } else {
        showError("Error fetching details");
      }
    } catch (e) {
      showError("Error: $e");
    } finally {
      setState(() => isProcessing = false);
    }
  }

  void showConfirmationDialog() {
    if (responsedata1 == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text("Confirm Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Name: ${responsedata1!['name']}",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Designation: ${responsedata1!['designation']}"),
              Text("Union: ${responsedata1!['unionName']}"),
              Text("Mobile: ${responsedata1!['mobileNumber']}"),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                setState(() => isProcessing = false);
              },
            ),
            IconButton(
              icon: Icon(Icons.check, color: Colors.green),
              onPressed: () {
                writeNfcData(responsedata1!['encryptednfcvalue']);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Helper: extract UID bytes and convert to decimal string (10 digits, left-padded)
  String _decimalUidFromTag(NfcTag tag) {
    try {
      final data = tag.data as Map;
      List<int>? idBytes;

      if (data['id'] is List<int> || data['id'] is Uint8List) {
        idBytes = List<int>.from(data['id']);
      } else if (data['nfca'] is Map && data['nfca']['identifier'] != null) {
        idBytes = List<int>.from(data['nfca']['identifier']);
      } else if (data['mifareclassic'] is Map && data['mifareclassic']['identifier'] != null) {
        idBytes = List<int>.from(data['mifareclassic']['identifier']);
      } else if (data['mifareultralight'] is Map && data['mifareultralight']['identifier'] != null) {
        idBytes = List<int>.from(data['mifareultralight']['identifier']);
      } else if (data['android'] is Map && data['android']['id'] != null) {
        idBytes = List<int>.from(data['android']['id']);
      } else if (data['identifier'] is List<int>) {
        idBytes = List<int>.from(data['identifier']);
      }

      if (idBytes == null || idBytes.isEmpty) return 'unknown';

      int val = 0;
      for (final b in idBytes) {
        val = (val << 8) | (b & 0xff);
      }
      String dec = val.toString();
      if (dec.length < 10) dec = dec.padLeft(10, '0');
      return dec;
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> writeNfcData(String encryptedData) async {
    if (!await NfcManager.instance.isAvailable()) {
      showError("NFC is not available");
      return;
    }

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      // Extract UID and print it immediately
      final decimalUid = _decimalUidFromTag(tag);
      print('NFC Tag UID (decimal,10): $decimalUid');

      var ndef = Ndef.from(tag);
      if (ndef == null || !ndef.isWritable) {
        showError("NFC tag is not writable");
        NfcManager.instance.stopSession(errorMessage: "Tag not writable");
        return;
      }
      try {
        NdefMessage message = NdefMessage([
          NdefRecord.createText(encryptedData),
        ]);
        await ndef.write(message);
        NfcManager.instance.stopSession();
        // Notify user and then start the server call with buffering overlay
        showError("NFC Write Successful");
        showSimplePopUp(context, "NFC Write Successful");

        setState(() => isBuffering = true);
        try {
          final vcidString = writewithcodevcid?.toString() ?? '';
          final result = await Apicalls.fetchDataAndWriteVcid(vcidString, decimalUid);
          setState(() => isBuffering = false);
          // Show server response
          final msg = result['statusdescription'] ?? result['message'] ?? 'Operation completed';
          showSimplePopUp(context, msg.toString());
        } catch (e) {
          setState(() => isBuffering = false);
          showError('Server call failed: $e');
        }
      } catch (e) {
        showError("NFC Write Failed");
        NfcManager.instance.stopSession(errorMessage: "Write Failed");
      }
    });
  }

  void showSimplePopUp(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Message'),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 25, right: 25),
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.start,
                overflow: TextOverflow.visible,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void initState() {
    super.initState();
    firstapi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VCID')),
      body: Stack(
        children: [
          // Empty center – actual interactions are via dialogs triggered by init flows
          const Center(child: SizedBox()),

          if (isBuffering) ...[
            const ModalBarrier(dismissible: false, color: Color(0x80000000)),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
