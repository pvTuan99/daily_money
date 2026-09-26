import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../camera/presentation/camera_screen.dart';
import 'presentation/auth_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.data != null) {
          return const CameraScreen();
        }

        return const AuthScreen();
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF111111),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
