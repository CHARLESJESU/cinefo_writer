import 'dart:convert';

import 'package:cinefonfcwriter/assets/variables.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:http/http.dart' as http;

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

  Future<void> writeNfcData(String encryptedData) async {
    if (!await NfcManager.instance.isAvailable()) {
      showError("NFC is not available");
      return;
    }

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
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
        showError("NFC Write Successful");
        showSimplePopUp(context, "NFC Write Successful");
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
      body: Center(
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
    );
  }
}
