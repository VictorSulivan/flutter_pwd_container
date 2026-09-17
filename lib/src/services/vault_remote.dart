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

  static const collection = 'coffres';
  static const contents = 'contenu';
  static const documentId = 'actuel';

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return _firestore
        .collection(collection)
        .doc(userId)
        .collection(contents)
        .doc(documentId);
  }

  List<DocumentReference<Map<String, dynamic>>> _legacyDocs(String userId) {
    return [
      _firestore.collection('vaults').doc(userId),
      _firestore.collection('users').doc(userId).collection('vault').doc('current'),
    ];
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
        throw StateError(
          'coffres/$userId/contenu/actuel ${error.code}: ${error.message}',
        );
      }
    }

    for (final legacy in _legacyDocs(userId)) {
      try {
        final snapshot = await legacy.get(
          const GetOptions(source: Source.server),
        );
        final data = snapshot.data();
        if (snapshot.exists && data != null && data.isNotEmpty) {
          return VaultEnvelope.fromFirestoreMap(data);
        }
      } on FirebaseException {
        continue;
      }
    }
    return null;
  }

  @override
  Future<void> write(String userId, VaultEnvelope envelope) async {
    const path = 'coffres/{uid}/contenu/actuel';
    final doc = _doc(userId);
    final resolved = 'coffres/$userId/contenu/actuel';
    try {
      await doc.set(envelope.toFirestoreMap());
      await _firestore.waitForPendingWrites();
      final confirmed = await doc.get(const GetOptions(source: Source.server));
      if (!confirmed.exists) {
        throw StateError('Firestore n’a pas confirmé $resolved');
      }
      debugPrint('Firestore wrote $resolved ($path = fiches chiffrées, pas le compte)');
    } on FirebaseException catch (error) {
      throw StateError('$resolved ${error.code}: ${error.message}');
    }
  }
}
