import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> copySecretToClipboard(
  BuildContext context,
  String value, {
  String copiedMessage = 'Copié. Presse-papier vidé dans 30 s.',
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copiedMessage)),
    );
  }
  unawaited(_clearClipboardLater(value));
}

Future<void> _clearClipboardLater(String value) async {
  await Future<void>.delayed(const Duration(seconds: 30));
  final current = await Clipboard.getData(Clipboard.kTextPlain);
  if (current?.text == value) {
    await Clipboard.setData(const ClipboardData(text: ''));
  }
}
