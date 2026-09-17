import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: AuthService.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const SizedBox.expand(),
    );
  }
}
