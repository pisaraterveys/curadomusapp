import 'package:flutter/material.dart';
import 'splash_screen.dart';

class CuradomusApp extends StatelessWidget {
  const CuradomusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curadomus',
      theme: ThemeData.dark(useMaterial3: true), // Dark mode as default
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
