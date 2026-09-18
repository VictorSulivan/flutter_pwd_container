import 'dart:convert';

import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PwnedPasswordHit {
  const PwnedPasswordHit({required this.count, this.checked = true});

  const PwnedPasswordHit.clean() : count = 0, checked = true;

  /// Réseau absent : on n’invente pas une fuite, on ne conclut pas non plus « propre ».
  const PwnedPasswordHit.unavailable() : count = 0, checked = false;

  final int count;
  final bool checked;

  bool get pwned => checked && count > 0;
}

abstract class PwnedPasswordsLookup {
  Future<PwnedPasswordHit> check(String password);

  Future<Map<String, PwnedPasswordHit>> checkEntries(
    List<({String id, String password})> entries,
  ) async {
    final hits = <String, PwnedPasswordHit>{};
    final pending = <String, List<String>>{};
    for (final entry in entries) {
      pending.putIfAbsent(entry.password, () => []).add(entry.id);
    }
    for (final password in pending.keys) {
      final hit = await check(password);
      for (final id in pending[password]!) {
        hits[id] = hit;
      }
    }
    return hits;
  }
}

class MemoryPwnedPasswords extends PwnedPasswordsLookup {
  MemoryPwnedPasswords([Map<String, PwnedPasswordHit>? hits])
    : _hits = hits ?? const {};

  final Map<String, PwnedPasswordHit> _hits;

  @override
  Future<PwnedPasswordHit> check(String password) async {
    return _hits[password] ?? const PwnedPasswordHit.clean();
  }
}

/// HIBP Pwned Passwords, k-anonymity : SHA-1 et comparaison **sur le téléphone**.
/// Seuls les 5 premiers caractères du hash hexadécimal quittent l’appareil.
class HibpPwnedPasswords extends PwnedPasswordsLookup {
  HibpPwnedPasswords({
    http.Client? client,
    this.fetchRange,
    this.endpoint = defaultEndpoint,
  }) : _client = client ?? http.Client();

  static const defaultEndpoint = 'https://api.pwnedpasswords.com/range/';
  static const userAgent = 'SafeVault/1.0';

  final http.Client _client;
  final Future<String> Function(String prefix)? fetchRange;
  final String endpoint;
  final Map<String, String> _rangeCache = {};
  final Map<String, Future<String>> _inflight = {};

  @override
  Future<PwnedPasswordHit> check(String password) async {
    if (password.isEmpty) {
      return const PwnedPasswordHit.clean();
    }
    try {
      final digest = _sha1Hex(password);
      final prefix = digest.substring(0, 5);
      final suffix = digest.substring(5);
      final body = await _range(prefix);
      for (final line in body.split(RegExp(r'\r?\n'))) {
        if (line.isEmpty) {
          continue;
        }
        final separator = line.indexOf(':');
        if (separator <= 0) {
          continue;
        }
        final candidate = line.substring(0, separator).trim().toUpperCase();
        final count = int.tryParse(line.substring(separator + 1).trim()) ?? 0;
        if (count > 0 && candidate == suffix) {
          return PwnedPasswordHit(count: count);
        }
      }
      return const PwnedPasswordHit.clean();
    } on Object catch (error) {
      debugPrint('HIBP range: $error');
      return const PwnedPasswordHit.unavailable();
    }
  }

  Future<String> _range(String prefix) {
    final cached = _rangeCache[prefix];
    if (cached != null) {
      return Future.value(cached);
    }
    return _inflight.putIfAbsent(prefix, () async {
      try {
        final body = await (fetchRange?.call(prefix) ?? _get(prefix));
        _rangeCache[prefix] = body;
        return body;
      } finally {
        _inflight.remove(prefix);
      }
    });
  }

  Future<String> _get(String prefix) async {
    final response = await _client.get(
      Uri.parse('$endpoint$prefix'),
      headers: {
        'User-Agent': userAgent,
        'Add-Padding': 'true',
        'Accept': 'text/plain',
      },
    );
    if (response.statusCode != 200) {
      throw StateError('HIBP HTTP ${response.statusCode}');
    }
    return response.body;
  }

  static String sha1PrefixForTest(String password) =>
      _sha1Hex(password).substring(0, 5);

  static String _sha1Hex(String password) {
    final digest = const DartSha1().hashSync(utf8.encode(password));
    final buffer = StringBuffer();
    for (final byte in digest.bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString().toUpperCase();
  }
}
