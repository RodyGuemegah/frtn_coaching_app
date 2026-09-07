import 'package:flutter/material.dart';
import '../services/auth_service.dart';



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => AuthService().signOut(),
          child: const Text('Déconnexion'),
        ),
      ),
    );
  }
} 