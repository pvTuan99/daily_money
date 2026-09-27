import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  runApp(DailyMoneyApp(firebaseReady: firebaseReady));
}
