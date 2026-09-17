import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'vault_envelope.dart';

class EncryptedFiche {
  const EncryptedFiche({
    required this.id,
    required this.ciphertext,
    required this.updatedAt,
  });

  final String id;
  final Uint8List ciphertext;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestoreMap() {
    return {
      'ciphertext': base64Encode(ciphertext),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory EncryptedFiche.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return EncryptedFiche(
      id: id,
      ciphertext: base64Decode(data['ciphertext'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String).toUtc(),
    );
  }
}

class RemoteVault {
  const RemoteVault({
    required this.envelope,
    required this.fiches,
  });

  final VaultEnvelope envelope;
  final List<EncryptedFiche> fiches;
}

abstract class VaultRemoteStore {
  Future<RemoteVault?> read(String userId);

  Future<void> write(String userId, RemoteVault vault);
}

class MemoryVaultRemoteStore implements VaultRemoteStore {
  MemoryVaultRemoteStore([Map<String, RemoteVault>? vaults])
    : _vaults = vaults ?? {};

  final Map<String, RemoteVault> _vaults;

  @override
  Future<RemoteVault?> read(String userId) async => _vaults[userId];

  @override
  Future<void> write(String userId, RemoteVault vault) async {
    _vaults[userId] = vault;
  }
}

/// Firestore :
/// users/{uid}                  nœud compte (pas de secret)
/// users/{uid}/enveloppe/actuelle   1 coffre (clé enveloppée)
/// users/{uid}/fiches/{id}          X mots de passe de sites, chiffrés
class FirestoreVaultRemoteStore implements VaultRemoteStore {
  FirestoreVaultRemoteStore([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> _enveloppe(String userId) {
    return _user(userId).collection('enveloppe').doc('actuelle');
  }

  CollectionReference<Map<String, dynamic>> _fiches(String userId) {
    return _user(userId).collection('fiches');
  }

  @override
  Future<RemoteVault?> read(String userId) async {
    try {
      final meta = await _enveloppe(userId).get(
        const GetOptions(source: Source.server),
      );
      if (meta.exists && meta.data() != null && meta.data()!.isNotEmpty) {
        final fichesSnap = await _fiches(userId).get(
          const GetOptions(source: Source.server),
        );
        return RemoteVault(
          envelope: VaultEnvelope.fromFirestoreMap(meta.data()!),
          fiches: [
            for (final doc in fichesSnap.docs)
              if (doc.data().isNotEmpty)
                EncryptedFiche.fromFirestore(doc.id, doc.data()),
          ],
        );
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied' && error.code != 'not-found') {
        throw StateError(
          'users/$userId/enveloppe ${error.code}: ${error.message}',
        );
      }
    }
    return _readLegacyBlob(userId);
  }

  Future<RemoteVault?> _readLegacyBlob(String userId) async {
    final legacy = [
      _firestore
          .collection('coffres')
          .doc(userId)
          .collection('contenu')
          .doc('actuel'),
      _firestore.collection('vaults').doc(userId),
      _firestore
          .collection('users')
          .doc(userId)
          .collection('vault')
          .doc('current'),
    ];
    for (final doc in legacy) {
      try {
        final snapshot = await doc.get(const GetOptions(source: Source.server));
        final data = snapshot.data();
        if (snapshot.exists && data != null && data.isNotEmpty) {
          return RemoteVault(
            envelope: VaultEnvelope.fromFirestoreMap(data),
            fiches: const [],
          );
        }
      } on FirebaseException {
        continue;
      }
    }
    return null;
  }

  @override
  Future<void> write(String userId, RemoteVault vault) async {
    final user = _user(userId);
    final enveloppe = _enveloppe(userId);
    final fiches = _fiches(userId);
    try {
      final existing = await fiches.get(const GetOptions(source: Source.server));
      final keep = {for (final fiche in vault.fiches) fiche.id};
      final batch = _firestore.batch();
      batch.set(user, const {'kind': 'coffre'});
      batch.set(enveloppe, vault.envelope.toFirestoreMetaMap());
      for (final fiche in vault.fiches) {
        batch.set(fiches.doc(fiche.id), fiche.toFirestoreMap());
      }
      for (final doc in existing.docs) {
        if (!keep.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
      await _firestore.waitForPendingWrites();
      final confirmed = await enveloppe.get(
        const GetOptions(source: Source.server),
      );
      if (!confirmed.exists) {
        throw StateError(
          'Firestore n’a pas confirmé users/$userId/enveloppe/actuelle',
        );
      }
      debugPrint(
        'Firestore wrote users/$userId/enveloppe/actuelle + ${vault.fiches.length} fiche(s)',
      );
    } on FirebaseException catch (error) {
      throw StateError(
        'users/$userId ${error.code}: ${error.message}',
      );
    }
  }
}
