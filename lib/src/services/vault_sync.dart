class VaultSyncException implements Exception {
  const VaultSyncException(this.cause);

  final Object cause;

  @override
  String toString() => 'Firestore: $cause';
}
