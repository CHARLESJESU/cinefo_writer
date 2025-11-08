import 'dart:convert';
import 'package:cinefonfcwriter/encryption.dart';
import "package:encrypt/encrypt.dart" as encrypt;

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NFCNotifier extends ChangeNotifier {
  bool _isProcessing = false;
  String _message = "";
  bool get isProcessing => _isProcessing;
  String get message => _message;
  String? decrypt1;

  Future<void> startNFCOperation(
      {required NFCOperation nfcOperation, String dataType = ""}) async {
    try {
      _isProcessing = true;
      notifyListeners();
      bool isAvail = await NfcManager.instance.isAvailable();
      if (isAvail) {
        if (nfcOperation == NFCOperation.read) {
          _message = "Scanning";
        }
        notifyListeners();
        NfcManager.instance.startSession(onDiscovered: (NfcTag nfcTag) async {
          if (nfcOperation == NFCOperation.read) {
            await _readFromTag(tag: nfcTag);
          }

          _isProcessing = false;
          notifyListeners();
          await NfcManager.instance.stopSession();
        }, onError: (e) async {
          _isProcessing = false;
          _message = e.toString();
          notifyListeners();
        });
      } else {
        _isProcessing = false;
        _message = "Please Enable NFC From Settings";
        notifyListeners();
      }
    } catch (e) {
      _isProcessing = false;
      _message = e.toString();
      notifyListeners();
    }
  }

  Future<void> _readFromTag({required NfcTag tag}) async {
    Map<String, dynamic> nfcData = {
      'nfca': tag.data['nfca'],
      'mifareultralight': tag.data['mifareultralight'],
      'ndef': tag.data['ndef']
    };

    String? decodedText;

    if (nfcData.containsKey('ndef')) {
      List<int> payload =
          nfcData['ndef']['cachedMessage']?['records']?[0]['payload'];

      if (payload.isNotEmpty) {
        int languageCodeLength = payload[0] & 0x3F;
        decodedText =
            String.fromCharCodes(payload.sublist(languageCodeLength + 1));
      }
    } else if (nfcData.containsKey('mifareultralight')) {
      List<int> mifareData = nfcData['mifareultralight']['data'];
      decodedText = String.fromCharCodes(mifareData);
    }

    _message = decodedText ?? "No Data Found";
    final String encryptedText = _message;

    final String encryptionKey = "VLABSOLUTION2023";
    final encrypt.IV iv = encrypt.IV.fromUtf8(encryptionKey);
    final decryptedText = decryptAES(encryptedText, encryptionKey, iv);
    Map<String, dynamic> data = jsonDecode(decryptedText);

    String formattedData = '''
Name: ${data["name"]}
VCID: ${data["vcid"]}
Mobile Number: ${data["mobileNumber"]}
Designation: ${data["designation"]}
Code: ${data["code"]}
Union Name: ${data["unionName"]}
''';

    _message = formattedData;
    notifyListeners();
  }
}

enum NFCOperation { read }
