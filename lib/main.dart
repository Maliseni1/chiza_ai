import 'package:flutter/material.dart';
import 'features/chat/presentation/screens/splash_screen.dart';

void main() {
  runApp(const ChizaApp());
}

class ChizaApp extends StatelessWidget {
  const ChizaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chiza AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
