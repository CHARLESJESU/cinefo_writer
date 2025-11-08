import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';

class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;
  String scannedUrl = "";
  String extractedVcid = "";
  Map? responsedata;
  Map? responsedata1;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!isProcessing) {
        controller.pauseCamera();

        setState(() {
          isProcessing = true;
          scannedUrl = scanData.code ?? "";
        });

        String? vcid = extractVcid(scannedUrl);
        if (vcid != null) {
          setState(() => extractedVcid = vcid);
          sendVcidToAPI(vcid);
        } else {
          showError("Invalid QR Code");
          setState(() => isProcessing = false);
          controller.resumeCamera();
        }
      }
    });
  }

  String? extractVcid(String url) {
    Uri? uri = Uri.tryParse(url);
    if (uri != null && uri.queryParameters.containsKey('vcid')) {
      String decodedVcid =
          Uri.decodeQueryComponent(uri.queryParameters['vcid']!);
      return decodedVcid.replaceAll(' ', '+');
    }
    return null;
  }

  Future<void> sendVcidToAPI(String vcid) async {
    String apiUrl = "https://vpack.vframework.in/vpackapi/Card/writeNFCinfo";
    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"data": vcid}),
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
        controller?.resumeCamera();
      }
    } catch (e) {
      showError("Error: $e");
      controller?.resumeCamera();
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
                controller?.resumeCamera();
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
    controller?.resumeCamera();
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
                controller?.resumeCamera(); // Resume camera after pop-up
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text("NFC Write"),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(
              key: qrKey,
              onQRViewCreated: onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Scanned URL:",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(scannedUrl.isNotEmpty ? scannedUrl : "No URL scanned",
                      textAlign: TextAlign.center),
                  SizedBox(height: 10),
                  Text("Extracted VCID:",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                      extractedVcid.isNotEmpty
                          ? extractedVcid
                          : "No VCID found",
                      textAlign: TextAlign.center),
                  SizedBox(height: 20),
                  isProcessing
                      ? CircularProgressIndicator()
                      : Text("Scan a QR Code"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
