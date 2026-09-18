import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router/app_navigator.dart';
import 'password_health.dart';
import 'security_alerts.dart';

abstract class SecurityNotificationPort {
  Future<bool> prepare();

  Future<void> sync(VaultHealthReport report);

  Future<void> notifyWeakPassword({
    required String serviceName,
    required String reason,
  });

  Future<void> clear();
}

class MemorySecurityNotifications implements SecurityNotificationPort {
  String? lastBody;
  bool prepared = false;

  @override
  Future<bool> prepare() async {
    prepared = true;
    return true;
  }

  @override
  Future<void> sync(VaultHealthReport report) async {
    lastBody = SecurityAlerts.trayBody(report);
    if (lastBody!.isEmpty) {
      lastBody = null;
    }
  }

  @override
  Future<void> notifyWeakPassword({
    required String serviceName,
    required String reason,
  }) async {
    lastBody = '$serviceName · $reason';
  }

  @override
  Future<void> clear() async {
    lastBody = null;
  }
}

/// Notification dans la barre du téléphone (même tiroir que les push).
/// FCM sert à demander la permission Android 13+ et à recevoir un message
/// distant. Les alertes du coffre sont affichées localement : aucun secret
/// ne part vers un serveur de push.
class SystemSecurityNotifications implements SecurityNotificationPort {
  SystemSecurityNotifications([
    FlutterLocalNotificationsPlugin? plugin,
    FirebaseMessaging? messaging,
  ]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _messaging = messaging ?? FirebaseMessaging.instance;

  static const _unlockId = 17;
  static const _weakId = 18;
  static const channelId = 'safevault_security_v2';
  static const _statusIcon = 'ic_stat_safevault';
  static const _markIcon = 'ic_safevault_mark';
  static const _accent = Color(0xFF3DDCFF);

  final FlutterLocalNotificationsPlugin _plugin;
  final FirebaseMessaging _messaging;
  bool _initialized = false;
  bool _prepared = false;
  bool _listening = false;

  Future<void> initializePlugin() async {
    if (_initialized || kIsWeb) {
      return;
    }
    const android = AndroidInitializationSettings(_statusIcon);
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        openSecurityFromNotification();
      },
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        'Alertes de sécurité',
        description: 'Mots de passe trop faibles, dupliqués ou trop anciens.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> prepare() async {
    if (kIsWeb) {
      return false;
    }
    if (_prepared) {
      return true;
    }
    try {
      await initializePlugin();
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidGranted =
          await androidPlugin?.requestNotificationsPermission();
      final enabled = await androidPlugin?.areNotificationsEnabled();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional ||
          androidGranted == true ||
          enabled == true;
      try {
        await _listenForPush();
        await _registerToken();
      } on Object catch (error) {
        debugPrint('FCM token: $error');
      }
      debugPrint(
        'Notifications: FCM=${settings.authorizationStatus} '
        'android=$androidGranted enabled=$enabled',
      );
      _prepared = granted;
      return granted;
    } on Object catch (error) {
      debugPrint('Notifications prepare: $error');
      return false;
    }
  }

  Future<void> _listenForPush() async {
    if (_listening) {
      return;
    }
    _listening = true;
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'SafeVault';
      final body =
          message.notification?.body ?? message.data['body'] ?? '';
      if (body.isEmpty) {
        return;
      }
      unawaited(
        _show(
          _unlockId,
          'SafeVault',
          title,
          body,
        ),
      );
    });
  }

  Future<void> _registerToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token)
        .set({
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'platform': defaultTargetPlatform.name,
        });
  }

  @override
  Future<void> sync(VaultHealthReport report) async {
    final body = SecurityAlerts.trayMessage(report);
    if (body.isEmpty) {
      await clear();
      return;
    }
    await initializePlugin();
    await _show(
      _unlockId,
      'SafeVault',
      'Santé du coffre',
      body,
    );
  }

  @override
  Future<void> notifyWeakPassword({
    required String serviceName,
    required String reason,
  }) async {
    await initializePlugin();
    await _show(
      _weakId,
      'SafeVault',
      'Mot de passe trop faible',
      'Le mot de passe de $serviceName est trop faible ($reason). '
          'Allonge-le et mélange majuscules, chiffres et symboles.',
    );
  }

  Future<void> _show(
    int id,
    String title,
    String subtitle,
    String body,
  ) async {
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: subtitle,
        payload: 'security',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Alertes de sécurité',
            channelDescription:
                'Doublons, mots de passe trop faibles ou trop anciens.',
            icon: _statusIcon,
            largeIcon: const DrawableResourceAndroidBitmap(_markIcon),
            color: _accent,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText: subtitle,
            ),
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            ticker: subtitle,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.status,
            actions: const [
              AndroidNotificationAction(
                'open_security',
                'Voir',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ],
          ),
        ),
      );
      debugPrint('Notification affichée: $body');
    } on Object catch (error) {
      debugPrint('Notification show: $error');
    }
  }

  @override
  Future<void> clear() async {
    if (!_initialized) {
      return;
    }
    try {
      await _plugin.cancel(id: _unlockId);
      await _plugin.cancel(id: _weakId);
    } on Object {
      // Plugin absent (tests, Linux).
    }
  }
}
