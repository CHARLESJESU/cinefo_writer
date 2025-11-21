import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'overwritefunction.dart';

class NfcDataEraseScreen extends StatefulWidget {
  const NfcDataEraseScreen({Key? key}) : super(key: key);

  @override
  State<NfcDataEraseScreen> createState() => _NfcDataEraseScreenState();
}
class _NfcDataEraseScreenState extends State<NfcDataEraseScreen> {
  bool _isAvailable = false;
  bool _scanning = false;
  String _status = 'Idle';
  String? _ndefText;
  String? _hexId;
  NfcTag? _currentTag;
  bool _awaitingFormatConfirmation = false;
  Timer? _operationTimer;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final available = await NfcManager.instance.isAvailable();
    setState(() => _isAvailable = available);
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _formatTag() async {
    if (!_isAvailable) {
      Fluttertoast.showToast(msg: 'NFC not available on this device');
      return;
    }

    setState(() {
      _scanning = true;
      _status = 'Waiting for tag...';
      _awaitingFormatConfirmation = false;
      _currentTag = null;
      _ndefText = null;
      _hexId = null;
    });

    _operationTimer?.cancel();
    _operationTimer = Timer(const Duration(seconds: 15), () async {
      try {
        await NfcManager.instance.stopSession(errorMessage: 'Operation timed out');
      } catch (_) {}
      if (mounted) {
        setState(() {
          _scanning = false;
          _status = 'Operation timed out';
          _awaitingFormatConfirmation = false;
          _currentTag = null;
        });
      }
      Fluttertoast.showToast(msg: 'No tag detected. Please try again.');
    });

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        _operationTimer?.cancel();

        String hex = '';
        String? ndefText;
        try {
          Uint8List? idBytes;
          final data = tag.data;
          if (data.containsKey('id') && data['id'] is Uint8List) {
            idBytes = data['id'];
          } else if (data['nfca'] != null && data['nfca'] is Map && data['nfca']['identifier'] is Uint8List) {
            idBytes = data['nfca']['identifier'];
          } else if (data['mifareclassic'] != null && data['mifareclassic'] is Map && data['mifareclassic']['identifier'] is Uint8List) {
            idBytes = data['mifareclassic']['identifier'];
          } else if (data['ndef'] != null && data['ndef'] is Map && data['ndef']['identifier'] is Uint8List) {
            idBytes = data['ndef']['identifier'];
          }

          if (idBytes == null) {
            for (final v in data.values) {
              if (v is Uint8List) {
                idBytes = v;
                break;
              }
              if (v is Map) {
                for (final nested in v.values) {
                  if (nested is Uint8List) {
                    idBytes = nested;
                    break;
                  }
                }
                if (idBytes != null) break;
              }
            }
          }

          if (idBytes != null) {
            hex = _bytesToHex(idBytes).toUpperCase();
            setState(() {
              _hexId = hex;
            });
          }

          final ndef = Ndef.from(tag);
          if (ndef != null) {
            final cached = ndef.cachedMessage;
            if (cached != null && cached.records.isNotEmpty) {
              final parts = <String>[];
              for (final r in cached.records) {
                try {
                  final payload = r.payload;
                  if (payload.isNotEmpty) {
                    final status = payload.first;
                    final langLen = status & 0x3F;
                    if (payload.length > 1 + langLen) {
                      final textBytes = payload.sublist(1 + langLen);
                      parts.add(utf8.decode(textBytes));
                      continue;
                    }
                  }
                  if (r.payload.isNotEmpty) parts.add(utf8.decode(r.payload));
                } catch (_) {
                  try {
                    parts.add(_bytesToHex(Uint8List.fromList(r.payload)));
                  } catch (_) {}
                }
              }
              ndefText = parts.join('\n');
            }
          }
        } catch (e) {
          debugPrint('Read extraction error: $e');
        }

        if (mounted) {
          setState(() {
            _scanning = true;
            _status = 'Tag found — confirm format';
            _ndefText = ndefText;
            _currentTag = tag;
            _awaitingFormatConfirmation = true;
          });
        }
      });
    } catch (e) {
      _operationTimer?.cancel();
      if (mounted) setState(() {
        _scanning = false;
        _status = 'Session start failed: $e';
      });
    }
  }

  Future<void> _confirmFormat() async {
    final tag = _currentTag;
    if (tag == null) {
      Fluttertoast.showToast(msg: 'No tag available to format');
      return;
    }

    setState(() {
      _status = 'Formatting...';
      _awaitingFormatConfirmation = false;
    });
    _operationTimer?.cancel();

    try {
      final ndef = Ndef.from(tag);
      if (ndef != null && ndef.isWritable) {
        final emptyRecord = NdefRecord.createText('');
        final message = NdefMessage([emptyRecord]);
        await ndef.write(message);
        try { await NfcManager.instance.stopSession(); } catch (_) {}
        if (mounted) setState(() { _scanning = false; _status = 'Format successful'; _ndefText = ''; _currentTag = null; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card formatted successfully')));
      } else {
        try { await NfcManager.instance.stopSession(errorMessage: 'Tag not writable'); } catch (_) {}
        if (mounted) setState(() { _scanning = false; _status = 'Tag not NDEF writable'; _currentTag = null; });
        Fluttertoast.showToast(msg: 'Tag not writable / unsupported');
      }
    } catch (e) {
      try { await NfcManager.instance.stopSession(errorMessage: e.toString()); } catch (_) {}
      // Attempt overwrite fallback
      final overwriteSuccess = await Overwritefunction.overwrite(context: context, payload: 'abc', showUI: false);
      if (overwriteSuccess) {
        if (mounted) setState(() { _scanning = false; _status = 'Format successful (overwrite)'; _ndefText = ''; _currentTag = null; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card formatted successfully (overwrite)')));
      } else {
        if (mounted) setState(() { _scanning = false; _status = 'Format failed: $e'; _currentTag = null; });
        Fluttertoast.showToast(msg: 'Format failed: $e');
      }
    }
  }

  Future<void> _cancelFormat() async {
    _awaitingFormatConfirmation = false;
    _operationTimer?.cancel();
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
    if (mounted) setState(() {
      _scanning = false;
      _status = 'Format cancelled';
      _currentTag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Format'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isAvailable) ...[
                  const Icon(Icons.nfc, size: 56, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('NFC is not available on this device'),
                ] else ...[
                  Icon(Icons.nfc, size: 56, color: _scanning ? Colors.blue : Colors.green),
                  const SizedBox(height: 8),
                  Text('Status: $_status'),
                  const SizedBox(height: 12),

                  const SizedBox(height: 12),
                  const Text('NDEF content:'),
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                    constraints: const BoxConstraints(maxHeight: 140, minWidth: double.infinity),
                    child: SingleChildScrollView(
                      child: Text(_ndefText == null || _ndefText!.isEmpty ? '<empty>' : _ndefText!),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _scanning ? null : _formatTag,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    icon: const Icon(Icons.format_clear),
                    label: const Text('Format your card'),
                  ),
                  const SizedBox(height: 8),
                  if (_hexId != null) Text('HEX UID: $_hexId'),
                  const SizedBox(height: 12),
                  if (_awaitingFormatConfirmation) ...[
                    Card(
                      color: Colors.yellow.shade50,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text('Confirm format? The tag will be overwritten.'),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: _confirmFormat,
                                  child: const Text('Confirm'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _cancelFormat,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                if (_scanning) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}