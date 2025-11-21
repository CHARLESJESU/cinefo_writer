import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:http/http.dart' as http;
import 'apifunctions.dart';

class WriteVcid extends StatefulWidget {
  const WriteVcid({super.key});

  @override
  State<WriteVcid> createState() => _WriteVcidState();
}

class _WriteVcidState extends State<WriteVcid> {
  TextEditingController vcidcontroller = TextEditingController();
  Map? responsedata;
  Map? responsedata1;
  bool isProcessing = false;
  bool isBuffering = false;
  String? firstresponsedata;
  Future<void> firstapii() async {
    String apiUrl = "https://vcrypt.vframework.in/vcryptapi/smallencrypt";
    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"data": vcidcontroller.text}),
      );

      if (response.statusCode == 200) {
        print(response.body);
        responsedata = jsonDecode(response.body);
        responsedata1 = responsedata!['data'];
        if (responsedata1!['response_description'] == "Success") {
          firstresponsedata = responsedata1!['data'];
          WriteVcidToAPI();
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

  Future<void> WriteVcidToAPI() async {
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

  // Helper: extract UID bytes from various possible tag data shapes and
  // convert to a decimal string. If shorter than 10 digits it will be left-
  // padded with zeros. If no UID found, returns 'unknown'.
  String _decimalUidFromTag(NfcTag tag) {
    try {
      final data = tag.data as Map; // cast to Map to avoid redundant 'is' check
      List<int>? idBytes;

      // Common places where UID bytes may appear in the tag map
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

      // Convert bytes (big-endian) to unsigned integer and then to decimal string
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
      // Extract and print the UID (decimal, padded to 10 digits) immediately
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
        // The UID has already been printed above; now show the success as a SnackBar
        // (avoid stacking multiple modal dialogs). Then show buffering dialog.
        showError("NFC Write Successful");

        // Show an in-page buffering overlay while we send the UID to the server.
        setState(() => isBuffering = true);

        // Send the VCID (from the input) and the NFC tag UID (decimalUid)
        // to the server. Clear the buffering state when finished and show
        // the server response or an error message.
        try {
          final apiResult = await Apicalls.fetchDataAndWriteVcid(
              vcidcontroller.text.trim(), decimalUid);
          setState(() => isBuffering = false);
          // Show server result if available
          final serverMsg = apiResult['statusdescription'] ?? apiResult['message'] ?? 'Operation completed';
          showSimplePopUp(context, serverMsg.toString());
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

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Write VCID")),
      // Use a Stack so we can show an in-page buffering overlay that blocks
      // interaction instead of using platform-dependent dialog APIs.
      body: Stack(
        children: [
          // Main scrollable content
          SingleChildScrollView(
            // Account for keyboard insets so bottom content isn't hidden
            padding: EdgeInsets.fromLTRB(0, 24, 0, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: TextField(
                      controller: vcidcontroller,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter VCID here',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (vcidcontroller.text.trim().isEmpty) {
                        showSimplePopUp(context, "Please enter a VCID");
                        return;
                      }
                      setState(() => isProcessing = true);
                      firstapii();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      elevation: 5,
                    ),
                    child: isProcessing
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : const Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Buffering overlay
          if (isBuffering) ...[
            const ModalBarrier(dismissible: false, color: Color(0x80000000)),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}