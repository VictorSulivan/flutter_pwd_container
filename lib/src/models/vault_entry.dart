import 'package:uuid/uuid.dart';

class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.serviceName,
    this.url,
    required this.username,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaultEntry.create({
    required String serviceName,
    String? url,
    required String username,
    required String password,
  }) {
    final now = DateTime.now().toUtc();
    return VaultEntry(
      id: const Uuid().v4(),
      serviceName: serviceName,
      url: url,
      username: username,
      password: password,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    return VaultEntry(
      id: json['id'] as String,
      serviceName: json['serviceName'] as String,
      url: json['url'] as String?,
      username: json['username'] as String,
      password: json['password'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  final String id;
  final String serviceName;
  final String? url;
  final String username;
  final String password;
  final DateTime createdAt;
  final DateTime updatedAt;

  VaultEntry copyWith({
    String? serviceName,
    String? url,
    bool clearUrl = false,
    String? username,
    String? password,
    DateTime? updatedAt,
  }) {
    return VaultEntry(
      id: id,
      serviceName: serviceName ?? this.serviceName,
      url: clearUrl ? null : (url ?? this.url),
      username: username ?? this.username,
      password: password ?? this.password,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceName': serviceName,
      'url': url,
      'username': username,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
