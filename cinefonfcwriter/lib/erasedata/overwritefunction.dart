import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:nfc_manager/nfc_manager.dart';

class Overwritefunction {
  /// Overwrite the NFC tag with the given [payload] (default: 'abc').
  ///
  /// Returns true on success, false on failure. When [showUI] is true and
  /// [context] is provided the method will show SnackBar/Toast messages; by
  /// default it does not show UI so callers can decide how to present results.
  static Future<bool> overwrite({BuildContext? context, String payload = 'abc', bool showUI = false}) async {
    // Check availability first
    final available = await NfcManager.instance.isAvailable();
    if (!available) {
      final msg = 'NFC not available on this device';
      if (showUI) {
        if (context != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        else Fluttertoast.showToast(msg: msg);
      }
      return false;
    }

    final completer = Completer<bool>();

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        if (completer.isCompleted) return;
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null || !ndef.isWritable) {
            final msg = 'Tag not writable or unsupported';
            try { await NfcManager.instance.stopSession(errorMessage: msg); } catch (_) {}
            if (showUI) {
              if (context != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              else Fluttertoast.showToast(msg: msg);
            }
            if (!completer.isCompleted) completer.complete(false);
            return;
          }

          // Create and write the NDEF message
          final record = NdefRecord.createText(payload);
          final message = NdefMessage([record]);
          await ndef.write(message);

          // Stop session and report success
          try { await NfcManager.instance.stopSession(); } catch (_) {}
          if (showUI) {
            final successMsg = 'Overwrite successful';
            if (context != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
            else Fluttertoast.showToast(msg: successMsg);
          }
          if (!completer.isCompleted) completer.complete(true);
          return;
        } catch (e) {
          try { await NfcManager.instance.stopSession(errorMessage: e.toString()); } catch (_) {}
          if (showUI) {
            final err = 'Overwrite failed: $e';
            if (context != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
            else Fluttertoast.showToast(msg: err);
          }
          if (!completer.isCompleted) completer.complete(false);
          return;
        }
      });

      // Wait for the completer to be completed by the onDiscovered handler or timeout
      try {
        final result = await completer.future.timeout(const Duration(seconds: 20), onTimeout: () => false);
        return result;
      } catch (_) {
        return false;
      }
    } catch (e) {
      // startSession failure
      if (showUI) {
        final err = 'NFC session start failed: $e';
        if (context != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        else Fluttertoast.showToast(msg: err);
      }
      if (!completer.isCompleted) completer.complete(false);
      return false;
    }
  }
}