import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'vault_envelope.dart';

abstract class VaultRemoteStore {
  Future<VaultEnvelope?> read(String userId);

  Future<void> write(String userId, VaultEnvelope envelope);
}

class MemoryVaultRemoteStore implements VaultRemoteStore {
  MemoryVaultRemoteStore([Map<String, VaultEnvelope>? envelopes])
    : _envelopes = envelopes ?? {};

  final Map<String, VaultEnvelope> _envelopes;

  @override
  Future<VaultEnvelope?> read(String userId) async => _envelopes[userId];

  @override
  Future<void> write(String userId, VaultEnvelope envelope) async {
    _envelopes[userId] = envelope;
  }
}

class FirestoreVaultRemoteStore implements VaultRemoteStore {
  FirestoreVaultRemoteStore([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return _firestore.collection('vaults').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> _legacyDoc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('vault')
        .doc('current');
  }

  @override
  Future<VaultEnvelope?> read(String userId) async {
    try {
      final snapshot = await _doc(userId).get(
        const GetOptions(source: Source.server),
      );
      final data = snapshot.data();
      if (snapshot.exists && data != null && data.isNotEmpty) {
        return VaultEnvelope.fromFirestoreMap(data);
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        throw StateError('vaults/$userId ${error.code}: ${error.message}');
      }
    }

    try {
      final legacy = await _legacyDoc(userId).get(
        const GetOptions(source: Source.server),
      );
      final data = legacy.data();
      if (!legacy.exists || data == null || data.isEmpty) {
        return null;
      }
      return VaultEnvelope.fromFirestoreMap(data);
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<void> write(String userId, VaultEnvelope envelope) async {
    final path = 'vaults/$userId';
    final doc = _doc(userId);
    try {
      await doc.set(envelope.toFirestoreMap());
      await _firestore.waitForPendingWrites();
      final confirmed = await doc.get(const GetOptions(source: Source.server));
      if (!confirmed.exists) {
        throw StateError('Firestore n’a pas confirmé $path');
      }
      debugPrint('Firestore wrote $path');
    } on FirebaseException catch (error) {
      throw StateError('$path ${error.code}: ${error.message}');
    }
  }
}
