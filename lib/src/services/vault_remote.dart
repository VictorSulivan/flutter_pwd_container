import 'package:cloud_firestore/cloud_firestore.dart';

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

  static const documentId = 'current';

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('vault')
        .doc(documentId);
  }

  @override
  Future<VaultEnvelope?> read(String userId) async {
    final snapshot = await _doc(userId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null || data.isEmpty) {
      return null;
    }
    return VaultEnvelope.fromFirestoreMap(data);
  }

  @override
  Future<void> write(String userId, VaultEnvelope envelope) {
    return _doc(userId).set(envelope.toFirestoreMap());
  }
}
