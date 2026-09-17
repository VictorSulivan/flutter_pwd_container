import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class SecureKeyStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }
}

class MemorySecureKeyStore implements SecureKeyStore {
  MemorySecureKeyStore([Map<String, String>? values]) : _values = values ?? {};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

abstract class EncryptedBlobStore {
  Future<Uint8List?> read(String userId);

  Future<void> write(String userId, Uint8List bytes);
}

class FileEncryptedBlobStore implements EncryptedBlobStore {
  FileEncryptedBlobStore({this.root});

  final Directory? root;

  @override
  Future<Uint8List?> read(String userId) async {
    final file = await _fileFor(userId);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<void> write(String userId, Uint8List bytes) async {
    final file = await _fileFor(userId);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<File> _fileFor(String userId) async {
    final root = this.root ?? await getApplicationSupportDirectory();
    final safeId = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File(p.join(root.path, 'vault_$safeId.enc'));
  }
}

class MemoryEncryptedBlobStore implements EncryptedBlobStore {
  MemoryEncryptedBlobStore([Map<String, Uint8List>? blobs])
    : _blobs = blobs ?? {};

  final Map<String, Uint8List> _blobs;

  @override
  Future<Uint8List?> read(String userId) async => _blobs[userId];

  @override
  Future<void> write(String userId, Uint8List bytes) async {
    _blobs[userId] = bytes;
  }
}
