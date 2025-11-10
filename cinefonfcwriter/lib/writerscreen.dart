import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:typed_data';
import 'package:cinefonfcwriter/writewithvcid/apifunctions.dart';

class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  @override
  void initState() {
    super.initState();
    developer.log('WriterScreen:initState', name: 'writerscreen');
  }
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;
  String scannedUrl = "";
  String extractedVcid = "";
  Map? responsedata;
  Map? responsedata1;
  bool isBuffering = false;

  @override
  void dispose() {
    developer.log('WriterScreen:dispose', name: 'writerscreen');
    try {
      controller?.dispose();
    } catch (e, st) {
      developer.log('Error disposing controller: $e', error: e, stackTrace: st, name: 'writerscreen');
    }
    super.dispose();
  }

  void onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    developer.log('QRView created, attaching scannedDataStream listener', name: 'writerscreen');
    try {
      controller.scannedDataStream.listen((scanData) {
        try {
          developer.log('scanData received: ${scanData.code}', name: 'writerscreen');
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
        } catch (e, st) {
          developer.log('Error handling scanData: $e', error: e, stackTrace: st, name: 'writerscreen');
          // Ensure camera resumes if we hit unexpected error during handling
          try {
            setState(() => isProcessing = false);
            controller.resumeCamera();
          } catch (_) {}
        }
      }, onError: (err, st) {
        developer.log('scannedDataStream reported error: $err', error: err, stackTrace: st, name: 'writerscreen');
      });
    } catch (e, st) {
      developer.log('Failed to attach scannedDataStream listener: $e', error: e, stackTrace: st, name: 'writerscreen');
    }
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
      developer.log('sendVcidToAPI response status: ${response.statusCode}', name: 'writerscreen');
      developer.log('sendVcidToAPI response body: ${response.body}', name: 'writerscreen');

      if (response.statusCode != 200) {
        // Non-200 — show raw response for debugging
        showSimplePopUp(context, 'encrypt API returned status ${response.statusCode}: ${response.body}');
        controller?.resumeCamera();
        return;
      }

      // Try to decode JSON safely and validate expected structure
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (e, st) {
        developer.log('sendVcidToAPI JSON decode failed', error: e, stackTrace: st, name: 'writerscreen');
        showSimplePopUp(context, 'encrypt API returned invalid JSON: ${response.body}');
        controller?.resumeCamera();
        return;
      }

      if (decoded is! Map) {
        showSimplePopUp(context, 'encrypt API returned unexpected body: ${response.body}');
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

    developer.log('Starting NFC session', name: 'writerscreen');
    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
       // Extract UID and print it immediately
       final decimalUid = _decimalUidFromTag(tag);
       print('NFC Tag UID (decimal,10): $decimalUid');
      developer.log('NFC tag discovered, uid: $decimalUid', name: 'writerscreen');

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
        String? vcidFromApi;
        try {
          // First, call the sendencryptVcidToAPI to get the encrypted vcid to use
          vcidFromApi = await Apicalls.sendencryptVcidToAPI(extractedVcid);
          print('sendencryptVcidToAPI returned: $vcidFromApi');

          // The encryption endpoint returns the VCID to send to registration.
          final vcidTrimmed = vcidFromApi.trim();
          if (vcidTrimmed.isEmpty) {
            setState(() => isBuffering = false);
            showSimplePopUp(context, 'Server returned an empty VCID');
          } else {
            try {
              final result = await Apicalls.fetchDataAndWriteVcid(vcidTrimmed, decimalUid);
              setState(() => isBuffering = false);
              final msg = result['statusdescription'] ?? result['message'] ?? 'Operation completed';
              showSimplePopUp(context, msg.toString());
            } catch (e) {
              setState(() => isBuffering = false);
              showError('Server call failed (${e.runtimeType}): ${e.toString()}');
            }
          }
        } on FormatException catch (fe) {
          setState(() => isBuffering = false);
          // Show a clearer message including the value returned by the first API when available
          showSimplePopUp(context, 'Invalid VCID format returned by server: ${vcidFromApi ?? fe.message}');
        } catch (e) {
          setState(() => isBuffering = false);
          showError('Server call failed (${e.runtimeType}): ${e.toString()}');
        }
      } catch (e) {
        showError("NFC Write Failed");
        NfcManager.instance.stopSession(errorMessage: "Write Failed");
        developer.log('NFC write failed: $e', error: e, name: 'writerscreen');
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
    developer.log('WriterScreen:build', name: 'writerscreen');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text("NFC Write"),
      ),
      // Use a Stack so we can display a centered buffering overlay
      body: Stack(
        children: [
          Column(
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
                  child: ListView(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Scanned URL:",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(scannedUrl.isNotEmpty ? scannedUrl : "No URL scanned",
                                textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            Text("Extracted VCID:",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(
                                extractedVcid.isNotEmpty
                                    ? extractedVcid
                                    : "No VCID found",
                                textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            isProcessing
                                ? const Center(child: CircularProgressIndicator())
                                : const Center(child: Text("Scan a QR Code")),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (isBuffering) ...[
            const ModalBarrier(dismissible: false, color: Color(0x80000000)),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
