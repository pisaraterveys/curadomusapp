import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'splash_screen.dart'; // 👈 use splash first

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final opts = DefaultFirebaseOptions.currentPlatform;
    debugPrint("🔧 Using FirebaseOptions: "
        "apiKey=${opts.apiKey}, "
        "appId=${opts.appId}, "
        "projectId=${opts.projectId}, "
        "storageBucket=${opts.storageBucket}");

    await Firebase.initializeApp(options: opts);
    debugPrint("✅ Firebase initialized successfully!");
  } catch (e, st) {
    debugPrint("❌ Firebase initialization failed: $e");
    debugPrint("StackTrace: $st");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curadomus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF89bcbe)),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // 👈 start here
    );
  }
}
